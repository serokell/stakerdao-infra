let
  sources = import ../nix/sources.nix;
  serokell-nix = sources."serokell.nix";

in {
  imports = [
    ./services/agora.nix
    ./services/blend-tender.nix

    "${serokell-nix}/modules/vault-secrets.nix"
  ];
}
