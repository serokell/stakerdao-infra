{ pkgs ? import ./nix {} }: with pkgs;
let
  tf = terraform_0_12.withPlugins(p: with p; [
    aws vault
  ]);
in

mkShell {
  buildInputs = [
      awscli
      bash
      jq
      niv
      nixopsUnstable
      tf
      vault-bin
  ];

  VAULT_ADDR = "https://vault.serokell.org:8200";

  NIX_PATH = builtins.concatStringsSep ":" [
    "nixpkgs=${toString pkgs.path}"
    "stakerdao-infra=${toString ./.}"
  ];
}
