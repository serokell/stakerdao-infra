{
  staging = {
    imports = [
      ./agora.nix
    ];

    networking.hostName = "agora-staging";
  };

  production = {
    imports = [
      ./agora.nix
    ];

    networking.hostName = "agora";
    services.nginx.virtualHosts.agora.serverAliases = [ "governance.stakerdao.com" ];
  };
}
