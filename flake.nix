{
  inputs = {
    nixpkgs.url = "github:serokell/nixpkgs";
    serokell-nix.url = "github:serokell/serokell.nix";
    deploy.url = "github:serokell/deploy";
  };

  outputs = { self, nixpkgs, serokell-nix, deploy }:
    let
      buildSystem = config:
        lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            serokell-nix.nixosModules.vault-secrets
            "${nixpkgs}/nixos/modules/virtualisation/amazon-image.nix"
            config
          ];
        };
      nodes = import ./nodes;
      lib = nixpkgs.lib;
    in {
      apps.x86_64-linux.deploy = deploy.defaultApp.x86_64-linux;

      nixosConfigurations = lib.mapAttrs (lib.const buildSystem) nodes;

      deploy = {
        sshOpts = "-o UserKnownHostsFile=${./.hosts}";
        user = "root";
        nodes = builtins.mapAttrs (_: system: {
          profiles.system = {
            path = system.config.system.build.toplevel;
            activate = "$PROFILE/bin/switch-to-configuration switch";
          };
          hostname = "${system.config.networking.hostName}.${system.config.networking.domain}";
        }) self.nixosConfigurations;
      };
    };
}
