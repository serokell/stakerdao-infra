{ pkgs, lib, config, ... }:

let
  cfg = config.services.agora;

  inherit (lib) mkOption mkEnableOption mkIf types;
  profile = "/nix/var/nix/profiles/agora";

  lootLogOptions = {
    backends = mkOption {
      # TODO: support other backends
      type = types.listOf (types.enum ["stderr"]);
      default = ["stderr"];
      apply = map (x: { type = x; });
    };
    min-severity = mkOption {
      type = types.enum ["Debug" "Info" "Warning" "Error"];
      default = "Warning";
    };
  };
in

{
  options.services.agora = {
    enable = mkEnableOption "agora";

    config = {
      api = {
        listen_addr = mkOption {
          type = types.str;
          default = "*:8190";
        };
        serve_docs = mkOption {
          type = types.bool;
          default = true;
        };
      };

      logging = lootLogOptions;

      contract = {
        address = mkOption {
          type = types.str;
          example = "KT1someContractAddressForExampleHere";
        };
        contract_block_level = mkOption {
          type = types.ints.positive;
          example = 176671;
        };
        contract_start = mkOption {
          type = types.str;
          example = "2020-01-01";
        };
      };

      node_addr = mkOption {
        type = types.str;
        example = "tezos.example.com:8732";
      };

      db = {
        conn_string = mkOption {
          type = types.str;
          default = "host=/run/postgresql dbname=agora";
        };
        max_connections = mkOption {
          type = types.ints.positive;
          default = 200;
        };
      };

      discourse = {
        host = mkOption {
          type = types.str;
          example = "https://discourse.example.com";
        };
        category = mkOption {
          type = types.str;
          default = "Proposals";
        };
        api_username = mkOption {
          type = types.str;
          default = "agora";
        };
        api_key = mkOption {
          type = types.str;
          example = "d06ca53322d1fbaf383a6394d6c229e56871342d2cad953a0fe26c19df7645ba";
        };
      };
    };
  };

  config = let
    configYaml = pkgs.writeTextFile {
      name = "config.yaml";
      text = builtins.toJSON cfg.config;
    };

    vs = config.vault-secrets.secrets;

  in mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [80 443];

    users.users.agora = {};

    vault-secrets.secrets.agora = {
      user = "agora";
      extraScript = ''
        source "$secretsPath/environment"
        export $(cut -d= -f1 "$secretsPath/environment")

        cat <<EOF >| "$secretsPath/secrets.yml"
        discourse:
          api_username: $DISCOURSE_USERNAME
          api_key: $DISCOURSE_TOKEN
        EOF
      '';
    };

    systemd.services.agora = rec {
      requires = [ "network.target" "postgresql.service" ];
      after = requires;
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${profile}/bin/agora -c ${configYaml} -c ${vs.agora}/secrets.yml";
        Restart = "always";
        User = "agora";
      };
    };

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_12;

      ensureDatabases = [ "agora" ];
      ensureUsers = [
        { name = "agora"; ensurePermissions = { "DATABASE \"agora\"" = "ALL"; }; }
        { name = "sashasashasasha151"; ensurePermissions = { "DATABASE \"agora\"" = "ALL"; }; }
      ];
    };

    services.nginx = {
      virtualHosts.agora = {
        locations = {
          "/api/".proxyPass = "http://127.0.0.1:8190";
          "/static/".alias = "${profile}/html/";
          "/" = {
            root = "${profile}/html";
            tryFiles = "/index.html =404";
            extraConfig = "add_header Cache-Control no-cache;";
          };
        };
      };
    };
  };
}
