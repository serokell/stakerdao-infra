{ pkgs, lib, config, ... }:

let
  cfg = config.services.blend-tender;

  inherit (lib) mkOption mkEnableOption mkIf types;
  profile = "/nix/var/nix/profiles/blend-tender";

  lootLogOptions = {
    backends = mkOption {
      # TODO: support other backends
      type = types.listOf (types.enum [ "stderr" ]);
      default = [ "stderr" ];
      apply = map (x: { type = x; });
    };
    min-severity = mkOption {
      type = types.enum [ "Debug" "Info" "Warning" "Error" ];
      default = "Warning";
    };
  };

in {
  options.services.blend-tender = {
    enable = mkEnableOption "blend-tender";

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
        cookies_length = mkOption {
          type = types.int;
          default = 20;
        };
        secure_cookies = mkOption {
          type = types.bool;
          default = false;
        };
        frontend_addr = mkOption {
          type = types.string;
          default =
            "https://${config.networking.hostName}.${config.networking.domain}";
        };
      };

      logging = lootLogOptions;

      db = {
        conn_string = mkOption {
          type = types.str;
          default = "host=/run/postgresql dbname=blnd";
        };
        max_connections = mkOption {
          type = types.ints.positive;
          default = 200;
        };
      };

      smtp = {
        host = mkOption {
          type = types.str;
          default = "<unset>";
        };
        logging = mkOption {
          type = types.str;
          default = "<unset>";
        };
        password = mkOption {
          type = types.str;
          default = "<unset>";
        };
        sender = mkOption {
          type = types.str;
          default = "<unset>";
        };
        token_length = mkOption {
          type = types.int;
          default = 50;
        };
        token_lifetime = mkOption {
          type = types.int;
          default = 3600;
          description = "Token lifetime (in seconds)";
        };
        email_subject = mkOption {
          type = types.str;
          default = "BLND tender password reset";
        };
        application_host = mkOption {
          type = types.str;
          default = "${config.networking.hostName}.${config.networking.domain}";
        };
      };
      web3 = {
        provider = mkOption {
          type = types.str;
          default = "<unset>";
        };
        blnd_address = mkOption {
          type = types.str;
          default = "<unset>";
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

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    users.users.blend-tender = { };

    vault-secrets.secrets.blend-tender = {
      user = "blend-tender";
      extraScript = ''
        source "$secretsPath/environment"
        export $(cut -d= -f1 "$secretsPath/environment")

        cat <<EOF >| "$secretsPath/secrets.yml"
        smtp:
          host: "$SMTP_HOST"
          logging: "$SMTP_LOGIN"
          password: "$SMTP_PASSWORD"
          sender: "$SMTP_SENDER"
        web3:
          provider: "$WEB3_PROVIDER"
          blnd_address: "$WEB3_BLND_ADDRESS"
        EOF
      '';
    };

    systemd.services.blend-tender = rec {
      requires = [ "network.target" "postgresql.service" ];
      after = requires;
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart =
          "${profile}/bin/blnd-tender -c ${configYaml} -c ${vs.blend-tender}/secrets.yml";
        Restart = "always";
        User = "blend-tender";
      };
    };

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_12;

      ensureDatabases = [ "blnd" ];
      ensureUsers = [{
        name = "blend-tender";
        ensurePermissions = { "DATABASE \"blnd\"" = "ALL"; };
      }];
    };

    services.nginx = {
      virtualHosts.blend-tender = {
        locations = {
          "/api/".proxyPass = "http://127.0.0.1:8190/";
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
