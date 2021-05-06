{ pkgs, lib, config, inputs, ... }: {

  imports = [
    inputs.serokell-nix.nixosModules.common
    inputs.serokell-nix.nixosModules.serokell-users
    inputs.serokell-nix.nixosModules.wireguard-monitoring
    inputs.vault-secrets.nixosModules.vault-secrets

    inputs.serokell-nix.nixosModules.ec2
  ];

  networking.domain = "stakerdao.serokell.team";

  vault-secrets = {
    vaultAddress = "https://vault.serokell.org:8200";
    vaultPrefix = "kv/sys/stakerdao/${config.networking.hostName}";
    approlePrefix = "stakerdao-${config.networking.hostName}";
  };

  services.nginx = {
    # SDAO-191
    eventsConfig = ''
      worker_connections 2048;
    '';
    logError = "stderr info";
  };

  serokell-users.wheelUsers =
    [ "gpevnev" "georgeee" "sashasashasasha151" ];
}
