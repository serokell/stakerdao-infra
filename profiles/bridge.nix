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


  security.sudo.extraRules = [{
    users = [ "deploy" ];
    commands = [
      {
        command = "/run/current-system/sw/bin/systemctl restart bridge";
        options = [ "NOPASSWD" ];
      }
    ];
  }];

  vault-secrets.secrets.${service} = {
    inherit user;
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_12;

    ensureUsers = map (name: {
      inherit name;
      ensurePermissions = { "DATABASE \"${dbname}\"" = "ALL"; };
    }) [ "gromak" "worm2fed" "georgeee" ];
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
      config = {
        chains.tezos.custom.endpoint = "http://edo.testnet.tezos.serokell.team:8732";
      };
      inherit user;
    };
  };
}
