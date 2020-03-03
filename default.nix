let
  pkgs = import ./nix {};
  inherit (pkgs) lib;

  shim = {
    boot.loader.systemd-boot.enable = true;

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
      fsType = "btrfs";
    };
  };

  buildSystem = config: (pkgs.nixos {
    imports = [ config shim ];
  }).config.system.build.toplevel;
  nodes = import ./nodes;
in
lib.mapAttrs (lib.const buildSystem) nodes
