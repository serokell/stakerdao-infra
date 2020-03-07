{ stdenv, rustPlatform, fetchFromGitHub, postgresql_11, zlib, openssl }:
let
  # master 20.07.2019 -- v1.4.2 doesn't seem to compile
  diesel-src = fetchFromGitHub {
    owner = "diesel-rs";
    repo = "diesel";
    rev = "066bc412d7ead423e71de811b1dac9428a63712c";
    sha256 = "0wsd27692hzbji5zsrk11kcbrp8m2zy5yfyd35drr40fyhhpryjx";
  };

  lockfile = ./Cargo.lock;
  diesel_cli-src = stdenv.mkDerivation {
    name = "diesel-src-1.4.3";
    src = "${diesel-src}";
    installPhase = ''
        mkdir -p $out
        cp -R $src/diesel_cli/* $out/
        cp ${lockfile} $out/Cargo.lock
    '';
  };
in

rustPlatform.buildRustPackage rec {
  name = "diesel_cli-${version}";
  version = "1.4.0";
  src = "${diesel_cli-src}";
  cargoSha256 = "1qb8nn0a2n2caxcpj8r563xrqk0va8vd7iwp5f3r83q09nk201kd";
  cargoBuildFlags = [
    "--no-default-features"
    "--features" "postgres"
  ];
  # The test suite wants to run sqlite/mysql tests
  doCheck = false;
  buildInputs = [ postgresql_11 zlib openssl ];
}
