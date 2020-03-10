{
  staging = {
    imports = [
      ./agora.nix
    ];

    networking.hostName = "agora-staging";
  };

  production = let
    cname = "governance.stakerdao.com";
  in {
    imports = [
      ./agora.nix
    ];

    networking.hostName = "agora";
    services.nginx.virtualHosts.agora.serverAliases = [ cname ];
  };
}
