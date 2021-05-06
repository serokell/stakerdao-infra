{
  imports = [ ../../profiles/blend-tender.nix ];

  networking.hostName = "blend";
  wireguard-ip-address = "172.21.0.26";
}
