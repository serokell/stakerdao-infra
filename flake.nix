{
  description = "NixOS systems for the stakerdao projects";

  inputs = {
    nixpkgs.url = "github:serokell/nixpkgs";
    stakerdao-agora = {
      url = "git+ssh://git@github.com/serokell/stakerdao-agora";
    };
    blend-app = {
      url = "git+ssh://git@github.com/stakerdao/blend-app";
    };
    bridge-web = {
      url = "git+ssh://git@github.com/stakerdao/bridge-web";
    };
    deploy-rs.url = "github:serokell/deploy-rs";
    serokell-nix.url = "github:serokell/serokell.nix";
  };

  outputs = { self, nixpkgs, serokell-nix, deploy-rs, ... }@inputs:
    let
      inherit (nixpkgs.lib) nixosSystem filterAttrs const recursiveUpdate;
      inherit (builtins) readDir mapAttrs;
      system = "x86_64-linux";
      servers = mapAttrs (path: _: import (./servers + "/${path}"))
        (filterAttrs (_: t: t == "directory") (readDir ./servers));
      mkSystem = config:
        nixosSystem {
          inherit system;
          modules = [ config ./common.nix ];
          specialArgs.inputs = inputs;
        };

      deployChecks =
        mapAttrs (_: lib: lib.deployChecks self.deploy) deploy-rs.lib;

      terraformFor = pkgs: pkgs.terraform.withPlugins (p: with p; [ aws ]);

      checks = mapAttrs (_: pkgs:
        let pkgs' = pkgs.extend serokell-nix.overlay;
        in {
          trailing-whitespace = pkgs'.build.checkTrailingWhitespace ./.;
          # terraform = pkgs'.build.validateTerraform {
            # src = ./terraform;
            # terraform = terraformFor pkgs;
          # };
        }) nixpkgs.legacyPackages;

    in {
      nixosConfigurations = mapAttrs (const mkSystem) servers;
      nixosSystems =
        builtins.mapAttrs (_: machine: machine.config.system.build.toplevel)
        self.nixosConfigurations;

      deploy.magicRollback = true;
      deploy.autoRollback = true;

      deploy.nodes = mapAttrs (_: nixosConfig: {
        hostname =
          "${nixosConfig.config.networking.hostName}.${nixosConfig.config.networking.domain}";
        sshOpts = [ "-p" "17788" ];

        profiles.system.user = "root";
        profiles.system.path =
          deploy-rs.lib.${system}.activate.nixos nixosConfig;
      }) self.nixosConfigurations;

      devShell = mapAttrs (system: deploy:
        let pkgs = nixpkgs.legacyPackages.${system}.extend serokell-nix.overlay;
        in pkgs.mkShell {
          buildInputs = [ deploy (terraformFor pkgs) pkgs.nixUnstable ];
        }) deploy-rs.defaultPackage;

      checks = recursiveUpdate deployChecks checks;
    };
}
