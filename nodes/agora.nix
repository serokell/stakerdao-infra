{ config, ... }:
let
  vs = config.vault-secrets.secrets;
  dns_name = "${config.networking.hostName}.${config.networking.domain}";
in {
  imports = [
    ./common.nix
  ];

  vault-secrets = {
    vaultAddress = "https://vault.serokell.org:8200";
    vaultPathPrefix = "kv/sys/stakerdao";
    namespace = config.networking.hostName;
  };

  services.agora = {
    enable = true;
    config = {
      api.listen_addr = "*:8190";
      node_addr = "mainnet.tezos.serokell.team:8732";
      db.conn_string =
        "dbname=agora user=agora";
      discourse = {
        api_username = "tezosagora";
        api_key = "<unset>";
      };
      logging.min-severity = "Info";
      contract = {
        address = "KT1EctCuorV2NfVb1XTQgvzJ88MQtWP8cMMv";
        contract_block_level = 767840;
      };
      discourse = {
        category = "Proposals Submitted";
        host = "https://forum.stakerdao.com";
      };
    };
  };

  networking.domain = "stakerdao.serokell.team";

  services.nginx.enable = true;
  services.nginx.virtualHosts.agora = {
    default = true;
    serverName = dns_name;
    forceSSL = true;
    enableACME = true;
  };

  security.acme = {
    email = "operations@serokell.io";
    acceptTerms = true;
  };
}
