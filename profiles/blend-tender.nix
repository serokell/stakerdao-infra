{ config, pkgs, inputs, ... }:
let
  profiles = "/nix/var/nix/profiles/per-user/deploy";
  dbname = "blnd";
  cfg = config.services.blend.backend;
  user = cfg.user;
  service = "blend-tender";
in {
  imports = [
    inputs.blend-app.nixosModules.combined
  ];

  users.users.deploy = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChyUoB/UYnKhx4TjTNWj4bJ+Z5Fn05zI3ONu38rb9Xk blend-app"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  vault-secrets.secrets.${service} = {
    inherit user;
  };

  services.blend = {
    enable = true;
    frontend = {
      package = "${profiles}/frontend";
    };
    backend = {
      package = "${profiles}/backend";
      secretFile = "${config.vault-secrets.secrets.${service}}/environment";
    };
  };
}
