{ config, pkgs, inputs, ... }:
let
  profiles = "/nix/var/nix/profiles/per-user/deploy";
  dbname = "bridge";
  cfg = config.services.bridge.backend;
  user = "bridge";
  service = "bridge";
in {
  imports = [ inputs.bridge-web.nixosModules.combined ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  users.users.deploy = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIImSq6l4MAGrbI3AyGa6JvP5wE0JtYBrXE52eISoJ8PA bridge-web"
    ];
  };


  vault-secrets.secrets.${service} = {
    inherit user;
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_12;

    ensureUsers = map (name: {
      inherit name;
      ensurePermissions = { "DATABASE \"${dbname}\"" = "ALL"; };
    }) [ "gpevnev" "sashasashasasha151" "georgeee" ];
  };

  services.bridge = {
    enable = true;
    frontend = {
      package = "${profiles}/frontend";
    };
    backend = {
      package = "${profiles}/backend";
      secretFile = "${config.vault-secrets.secrets.${service}}/environment";
      serviceName = service;
      inherit user;
    };
  };
}
