{ config, ... }:
let
  vs = config.vault-secrets.secrets;
  dns_name = "${config.networking.hostName}.${config.networking.domain}";
in {
  imports = [
    ./common.nix
  ];

  vault-secrets = {
    vaultAddress = "https://vault.serokell.org:8200";
    vaultPathPrefix = "kv/sys/stakerdao";
    namespace = config.networking.hostName;
  };

  services.blend-tender.enable = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts.blend-tender = {
    default = true;
    serverName = dns_name;
    forceSSL = true;
    enableACME = true;
  };
}
