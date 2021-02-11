{
  imports = [ ../../profiles/agora.nix ];

  networking.hostName = "agora";
  services.agora.frontend.fqdn = "governance.stakerdao.com";
}
