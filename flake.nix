{
  inputs = {
    nixpkgs.url = "github:serokell/nixpkgs";
    common-infra = {
      url = "github:serokell/common-infra";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    serokell-nix = {
      url = "github:serokell/serokell.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, common-infra, serokell-nix }@inputs:
    let
      hosts = builtins.path {
        name = "hosts";
        path = ./.hosts;
      };
    in {
      mkDeploy = name:
        { nixosModules, profiles, ... }: {
          nodes = builtins.mapAttrs (_: config:
            common-infra.mkNode {
              deployKey =
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGItnQMIZO55M7hnlAcJ9z4a0IWHajZxd3cBrESR6HpN deploy";
              modules = [
                config
                serokell-nix.nixosModules.vault-secrets
                "${nixpkgs}/nixos/modules/virtualisation/amazon-image.nix"
              ] ++ (builtins.attrValues nixosModules);
              packages = profiles.x86_64-linux;
            }) (import ./nodes).${name};
          sshOpts = [ "-o UserKnownHostsFile=${hosts}" ];
        };
      mkPipelineFile = { deploy, packages ? { }, profiles ? { }, checks ? { }, ... }:
        common-infra.mkPipelineFile {
          inherit deploy packages checks;
          deployFromPipeline = builtins.concatMap (branch:
            map (profile: { inherit branch profile; })
            (builtins.attrNames profiles.x86_64-linux))
            (builtins.attrNames deploy.nodes);
          agents = [ "private=true" ];
        };
    };
}
