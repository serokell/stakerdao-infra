{
  description = "NixOS systems for the stakerdao projects";

  nixConfig = {
    flake-registry = "https://github.com/serokell/flake-registry/raw/master/flake-registry.json";
  };

  inputs = {
    stakerdao-agora.url = "git+ssh://git@github.com/serokell/stakerdao-agora";
    bridge-web.url = "git+ssh://git@github.com/stakerdao/bridge-web";
  };

  outputs =
    { self, nixpkgs, serokell-nix, deploy-rs, vault-secrets, ... }@inputs:
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

      deploy = {
        magicRollback = true;
        autoRollback = true;

        sshOpts = [ "-p" "17788" ];

        nodes = mapAttrs (_: nixosConfig: {
          hostname =
            "${nixosConfig.config.networking.hostName}.${nixosConfig.config.networking.domain}";

          profiles.system.user = "root";
          profiles.system.path =
            deploy-rs.lib.${system}.activate.nixos nixosConfig;
        }) self.nixosConfigurations;
      };
      devShell = mapAttrs (system: deploy:
        let
          pkgs = serokell-nix.lib.pkgsWith nixpkgs.legacyPackages.${system} [
            serokell-nix.overlay
            vault-secrets.overlay
          ];
        in pkgs.mkShell {
          VAULT_ADDR = "https://vault.serokell.org:8200";
          SSH_OPTS = "${builtins.concatStringsSep " " self.deploy.sshOpts}";
          buildInputs = [
            deploy-rs.packages.${system}.deploy-rs
            pkgs.vault
            (pkgs.vault-push-approle-envs self)
            (pkgs.vault-push-approles self)
            (terraformFor pkgs)
            pkgs.nixUnstable
          ];
        }) deploy-rs.defaultPackage;

      checks = recursiveUpdate deployChecks checks;
    };
}
