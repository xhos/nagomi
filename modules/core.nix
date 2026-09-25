{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.core;
  nagomi = import ./lib.nix {inherit config lib;};
  inherit (lib) mkIf optionalAttrs;
in {
  options.services.nagomi.core = nagomi.serviceOptions "core" 55555;

  config = mkIf cfg.enable {
    services.nagomi.core.environment = nagomi.mkEnv ({
        LISTEN_ADDRESS = "127.0.0.1:${toString svc.port}";
        LOG_LEVEL = cfg.logLevel;
        LOG_FORMAT = cfg.logFormat;
        DATABASE_URL = "postgresql:///nagomi?host=/run/postgresql";
        EXCHANGE_API_URL = "https://api.frankfurter.dev/v2";
        NAGOMI_GATEWAY_URL = "http://127.0.0.1:${toString cfg.gateway.port}";
        S3_ENDPOINT = "http://127.0.0.1:${toString cfg.storage.s3Port}";
        S3_BUCKET = cfg.storage.bucket;
        S3_REGION = cfg.storage.region;
      }
      // optionalAttrs cfg.receipts.enable {
        NAGOMI_RECEIPTS_URL = "http://127.0.0.1:${toString cfg.receipts.port}";
      }
      // optionalAttrs cfg.statements.enable {
        NAGOMI_STATEMENTS_URL = "http://127.0.0.1:${toString cfg.statements.port}";
      });

    systemd.services.nagomi-core = nagomi.mkService "core" {
      inherit (svc) environment secretsFile;
      description = "core backend";
      exe = lib.getExe' svc.package "nagomi";
      requires = ["nagomi-db-setup.service" "nagomi-storage-setup.service"];
    };
  };
}
