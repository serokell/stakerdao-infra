{ pkgs, lib, config, inputs, ... }:
let
  inherit (builtins) toString typeOf;
  inherit (lib) collect;
  inherit (pkgs) writeText;

  profile-root = "/nix/var/nix/profiles/per-user/deploy";
in {
  imports = [
    inputs.stakerdao-agora.nixosModules.combined
  ];

  users.users.deploy = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      # Used by stakerdao-agora CI
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGItnQMIZO55M7hnlAcJ9z4a0IWHajZxd3cBrESR6HpN deploy"
    ];
  };

  security.sudo.extraRules = [{
    users = [ "deploy" ];
    commands = [
      {
        command = "/run/current-system/sw/bin/systemctl restart agora";
        options = [ "NOPASSWD" ];
      }
    ];
  }];

  vault-secrets.secrets.agora = { user = "agora"; };

  services.agora = {
    enable = true;
    frontend = { package = "${profile-root}/agora-frontend"; };
    backend = {
      package = "${profile-root}/agora-backend";
      secretFile = "${config.vault-secrets.secrets.agora}/environment";
      config = {
        discourse = {
          proposal_category = "Proposals Submitted";
          implementation_category = "Implementation Progress";
          host = "https://forum.stakerdao.com";
        };
      };
    };
  };

  services.nginx.enable = true;

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx.virtualHosts.agora = { default = true; };

  services.postgresql.package = pkgs.postgresql_12;
}
