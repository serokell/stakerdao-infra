{
  agora-staging = {
    imports = [
      ./agora.nix
    ];

    networking.hostName = "agora-staging";
  };

  agora-production = let
    cname = "governance.stakerdao.com";
  in {
    imports = [
      ./agora.nix
    ];

    networking.hostName = "agora";
    services.nginx.virtualHosts.agora.serverAliases = [ cname ];
  };

  blend-demo = {
    imports = [ ./blend-tender.nix ];

    networking.hostName = "blend";
  };
}
