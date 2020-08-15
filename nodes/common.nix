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

  service-activate = pkgs.writeShellScriptBin "service-activate" ''
    set -euo pipefail

    if [[ -z ''${1:-} ]]; then
      echo "Missing argument: service profile name."
      exit 1
    fi

    if [[ -z ''${2:-} ]]; then
      echo "Missing argument: full path to valid service closure."
      exit 1
    fi

    if [[ ! -d ''${2:-} ]]; then
      echo "''${1:-} is not a folder or does not exist."
      exit 1
    fi

    echo 'Activating service closure...'
    nix-env --profile "$1" --set "$2"
    systemctl restart "$(basename "$1")"
  '';

  system-activate = pkgs.writeShellScriptBin "system-activate" ''
    set -euo pipefail

    if [[ -z ''${1:-} ]]; then
      echo "Missing argument: full path to valid system closure."
      exit 1
    fi

    if [[ ! -d ''${1:-} ]]; then
      echo "''${1:-} is not a folder or does not exist."
      exit 1
    fi

    if [[ ! -x ''${1:-}/bin/switch-to-configuration ]]; then
      echo "''${1:-} is not a valid system closure: `bin/switch-to-configuration` not found or not executable."
      exit 1
    fi

    echo 'Activating system closure...'
    "$1/bin/switch-to-configuration" switch
  '';
in {

  imports = [
    ../modules
  ];

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
    service-activate
    system-activate
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

  security.sudo.extraRules = [
    {
      users = [ "buildkite" ];
      commands = [
        { command = "/run/current-system/sw/bin/system-activate *";
        options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/service-activate *";
        options = [ "NOPASSWD" ]; }
      ];
    }
  ];

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
