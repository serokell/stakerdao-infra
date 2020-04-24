{ config, ... }:
let
  dns_name = "${config.networking.hostName}.${config.networking.domain}";
in {
  imports = [
    ./common.nix
  ];

  services.blend-tender.enable = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts.blend-tender = {
    default = true;
    serverName = dns_name;
    forceSSL = true;
    enableACME = true;
  };
}
