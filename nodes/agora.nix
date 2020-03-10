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

  vault-secrets.secrets.acme-sh = {
    inherit (config.services.nginx) user;
    services = [ "acme-sh-agora" ];
  };

  services.acme-sh.certs.agora = {
    domains."${dns_name}" = "dns_aws";
    mainDomain = dns_name;
    postRun = "systemctl reload nginx || true";
    keyFile = "${vs.acme-sh}/environment";
    production = true;
    inherit (config.services.nginx) user group;
  };

  services.nginx.enable = true;
  services.nginx.virtualHosts.agora = let
    cert = config.services.acme-sh.certs.agora;
  in {
    default = true;
    serverName = dns_name;

    forceSSL = true;
    sslCertificate = cert.certPath;
    sslCertificateKey = cert.keyPath;
  };
}
