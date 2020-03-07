{ pkgs ? import ./nix {} }: with pkgs;
let
  src = ./.;
  version = "0.1.0";
in rec {
  deploy = rustPlatform.buildRustPackage rec {
    inherit src version;
    name = "deploy-${version}";
    cargoSha256 = "0jbzd3wpswfqwwhimf5v4aflg8zn83mpzp9cvnlpyhkigyiinwhw";
    buildInputs = [ pkgconfig zlib openssl ];
    shellHook = ''
      export RUST_BACKTRACE=1
    '';
  };
}
