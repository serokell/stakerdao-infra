{ pkgs ? import ./nix {} }: with pkgs;
let
  tf = terraform_0_12.withPlugins(p: with p; [
    aws
  ]);
in

mkShell {
  buildInputs = [
      tf
  ];
}
