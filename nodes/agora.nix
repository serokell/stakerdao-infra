{ config, pkgs, ... }:
let
  vs = config.vault-secrets.secrets;
  profile = "/nix/var/nix/profiles/per-user/agora/agora-frontend";
  dns_name = "${config.networking.hostName}.${config.networking.domain}";
in {
  imports = [ ./common.nix ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  users.users.agora = {
    isNormalUser = true;
  };

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

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_12;

    ensureDatabases = [ "agora" ];
    ensureUsers = [
      {
        name = "agora";
        ensurePermissions = { "DATABASE \"agora\"" = "ALL"; };
      }
      {
        name = "sashasashasasha151";
        ensurePermissions = { "DATABASE \"agora\"" = "ALL"; };
      }
    ];
  };

  services.nginx = {
    enable = true;
    virtualHosts.agora = {
      default = true;
      serverName = dns_name;
      forceSSL = true;
      enableACME = true;
      locations = {
        "/api/".proxyPass = "http://127.0.0.1:8190";
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
