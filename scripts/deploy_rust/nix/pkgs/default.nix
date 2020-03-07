self: super:
let
  inherit (self) callPackage;
in
{
  diesel_cli = callPackage ./diesel_cli {};
}
