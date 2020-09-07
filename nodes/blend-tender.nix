{ config, pkgs, ... }:
let
  profiles = "/nix/var/nix/profiles/per-user/deploy";
  dbname = "blnd";
  cfg = config.services.blend.backend;
  user = cfg.user;
  service = cfg.serviceName;
in {
  imports = [ ./common.nix ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  vault-secrets.secrets.${service} = {
    inherit user;
    extraScript = ''
      source "$secretsPath/environment"
      export $(cut -d= -f1 "$secretsPath/environment")

      cat <<EOF >| "$secretsPath/secrets.yml"
      smtp:
        host: "$SMTP_HOST"
        logging: "$SMTP_LOGIN"
        password: "$SMTP_PASSWORD"
        sender: "$SMTP_SENDER"
      eth:
        provider: "$ETH_PROVIDER"
        tender_address_transfer_topic: "$ETH_TENDER_ADDRESS"
        contract_addrs:
          blnd: "$ETH_BLND_ADDRESS"
          orchestrator: "$ETH_ORCHESTRATOR_ADDRESS"
          registry: "$ETH_REGISTRY_ADDRESS"
      EOF
    '';
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_12;

    ensureDatabases = [ dbname ];
    ensureUsers = map (name: {
      inherit name;
      ensurePermissions = { "DATABASE \"${dbname}\"" = "ALL"; };
    }) [ user "gpevnev" "sashasashasasha151" "georgeee" ];
  };

  services.blend = {
    frontend = {
      enable = true;
      package = "${profiles}/frontend";
    };
    backend = {
      enable = true;
      package = "${profiles}/backend";
      secrets = config.vault-secrets.secrets.${service};
      config.db.conn_string = "host=/run/postgresql dbname=${dbname}";
    };
  };
}
