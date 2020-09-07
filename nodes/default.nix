{
  agora = {
    staging = {
      imports = [ ./agora.nix ];

      networking.hostName = "agora-staging";
    };

    production = {
      imports = [ ./agora.nix ];

      networking.hostName = "agora";
      services.agora.frontend.fqdn = "governance.stakerdao.com";
    };
  };

  blend = {
    demo = {
      imports = [ ./blend-tender.nix ];

      networking.hostName = "blend";
    };
  };
}
