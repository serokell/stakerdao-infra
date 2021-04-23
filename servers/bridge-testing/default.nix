{
  imports = [ ../../profiles/bridge.nix ];
  networking.hostName = "bridge";
  wireguard-ip-address = "172.21.0.27";
}
