{ mkDerivation, async, base, bytestring, HSH, optparse-applicative
, process, stdenv, text
}:
mkDerivation {
  pname = "deploy";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    async base bytestring HSH optparse-applicative process text
  ];
  description = "Deploy Agora";
  license = "unknown";
  hydraPlatforms = stdenv.lib.platforms.none;
}
