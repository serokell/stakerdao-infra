{ pkgs, lib, config, inputs, ... }: {

  imports = [
    inputs.serokell-nix.nixosModules.common
    inputs.serokell-nix.nixosModules.serokell-users
    inputs.serokell-nix.nixosModules.vault-secrets
    "${inputs.nixpkgs}/nixos/modules/virtualisation/amazon-image.nix"
  ];

  networking.domain = "stakerdao.serokell.team";

  vault-secrets = {
    vaultAddress = "https://vault.serokell.org:8200";
    vaultPathPrefix = "kv/sys/stakerdao";
    namespace = config.networking.hostName;
    approlePrefix = "stakerdao-${config.networking.hostName}";
  };

  networking.firewall.allowedTCPPorts =
    [ config.services.prometheus.exporters.node.port ];

  services.nginx = {
    # SDAO-191
    eventsConfig = ''
      worker_connections 2048;
    '';
    logError = "stderr info";
  };

  serokell-users.wheelUsers =
    [ "gpevnev" "georgeee" "sashasashasasha151" ];

  systemd.services.amazon-init.enable = false;
}
