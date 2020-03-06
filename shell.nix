{ pkgs ? import ./nix {} }: with pkgs;
let
  tf = terraform_0_12.withPlugins(p: with p; [
    aws
  ]);
in

mkShell {
  buildInputs = [
      nixopsUnstable
      tf
  ];

  VAULT_ADDR = "https://vault.serokell.org:8200";

  NIX_PATH = builtins.concatStringsSep ":" [
    "nixpkgs=${toString pkgs.path}"
    "stakerdao-infra=${toString ./.}"
  ];
}
