{ config, pkgs, ... }:
let
  dns_name = "${config.networking.hostName}.${config.networking.domain}";
  profile = "/nix/var/nix/profiles/per-user/blend-tender/blend-frontend";
in {
  imports = [ ./common.nix ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  users.users.blend-tender = {
    isNormalUser = true;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGItnQMIZO55M7hnlAcJ9z4a0IWHajZxd3cBrESR6HpN blend"
    ];
  };

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
      eth:
        provider: "$ETH_PROVIDER"
        blnd_address: "$ETH_BLND_ADDRESS"
      EOF
    '';
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_12;

    ensureDatabases = [ "blnd" ];
    ensureUsers = map (name: {
      inherit name;
      ensurePermissions = { "DATABASE \"blnd\"" = "ALL"; };
    }) [ "blend-tender" "gpevnev" "sashasashasasha151" "georgeee" ];
  };

  services.nginx = {
    enable = true;
    virtualHosts.agora = {
      default = true;
      serverName = dns_name;
      forceSSL = true;
      enableACME = true;
      locations = {
        "/api/".proxyPass = "http://127.0.0.1:8190/";
        "/static/".alias = "${profile}/";
        "/" = {
          root = profile;
          tryFiles = "/index.html =404";
          extraConfig = "add_header Cache-Control no-cache;";
        };
      };
    };
  };
}
