{ sources ? import ./sources.nix }:
[(self: super: {
  inherit (self.callPackage sources.niv {}) niv;
})]
