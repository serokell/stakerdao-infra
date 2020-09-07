{ pkgs, lib, config, ... }:
let
  wheel = [ "chris" "kirelagin" "balsoft" "sashasashasasha151" "zhenya" "gpevnev" ];
  expandUser = _name: keys: {
    extraGroups =
      (lib.optionals (builtins.elem _name wheel) [ "wheel" ])
      ++ [ "systemd-journal" ];
      isNormalUser = true;
      openssh.authorizedKeys.keys = keys;
  };

in {

  networking.domain = "stakerdao.serokell.team";

  vault-secrets = {
    vaultAddress = "https://vault.serokell.org:8200";
    vaultPathPrefix = "kv/sys/stakerdao";
    namespace = config.networking.hostName;
  };

  security.acme = {
    email = "operations@serokell.io";
    acceptTerms = true;
  };

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    disabledCollectors = [ "timex" ];
  };

  networking.firewall.allowedTCPPorts = [
    config.services.prometheus.exporters.node.port
  ];

  environment.systemPackages = with pkgs; [
    awscli
  ];

  # https://github.com/NixOS/nix/issues/1964
  nix.extraOptions = ''
    tarball-ttl = 0
  '';

  documentation.nixos.enable = false;
  nixpkgs.config.allowUnfree = true;
  nix.autoOptimiseStore = true;
  nix.gc = {
    automatic = true;
    # delete so there is 15GB free, and delete very old generations
    # delete-older-than by itself will still delete all non-referenced packages (ie build dependencies)
    options = lib.mkForce ''
      --max-freed "$((15 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))" --delete-older-than 14d'';
  };

  security.sudo.wheelNeedsPassword = false;

  users.mutableUsers = false;
  users.users = lib.mapAttrs expandUser (import ./ssh-keys.nix);

  services.nginx = {
    # SDAO-191
    eventsConfig = ''
      worker_connections 2048;
    '';
    logError = "stderr info";
  };
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };

  networking.firewall = {
    allowPing = false;
    logRefusedConnections = false;
  };

  nix.binaryCachePublicKeys = [ "serokell-1:aIojg2Vxgv7MkzPJoftOO/I8HKX622sT+c0fjnZBLj0=" ];
}
