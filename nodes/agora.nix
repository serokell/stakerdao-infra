{ config, pkgs, ... }:
let
  profiles = "/nix/var/nix/profiles/per-user/deploy";
  dbname = "agora";
  cfg = config.services.agora.backend;
  user = cfg.user;
  service = cfg.serviceName;
in {
  imports = [ ./common.nix ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  vault-secrets.secrets.agora = {
    user = "agora";
    extraScript = ''
      source "$secretsPath/environment"
      export $(cut -d= -f1 "$secretsPath/environment")

      cat <<EOF >| "$secretsPath/secrets.yml"
      contract:
        address: "$CONTRACT_ADDRESS"
      discourse:
        api_username: $DISCOURSE_USERNAME
        api_key: $DISCOURSE_TOKEN
      EOF
    '';
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_12;

    ensureDatabases = [ dbname ];
    ensureUsers = [
      {
        name = user;
        ensurePermissions = { "DATABASE \"${dbname}\"" = "ALL"; };
      }
      {
        name = "sashasashasasha151";
        ensurePermissions = { "DATABASE \"${dbname}\"" = "ALL"; };
      }
    ];
  };

  services.agora = {
    frontend = {
      enable = true;
      package = "${profiles}/frontend";
    };
    backend = {
      enable = true;
      package = "${profiles}/backend";
      secrets = config.vault-secrets.secrets.${service};
      config = {
        discourse.host = "https://forum.stakerdao.com";
        db.conn_string = "host=/run/postgresql dbname=${dbname}";
        node_addr = "https://mainnet-tezos.giganode.io";
        discourse = {
          implementation_category = "Implementation Progress";
          proposal_category = "Proposals Submitted";
        };
      };
    };
  };
}
