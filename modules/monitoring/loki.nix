{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.monitoring;
  dataDir = config.services.loki.dataDir;
in {
  config = lib.mkIf (cfg.enable && svc.enable) {
    services.loki = {
      enable = true;

      # single binary, everything on the local filesystem
      configuration = {
        auth_enabled = false;
        analytics.reporting_enabled = false;

        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = svc.loki.port;
          grpc_listen_address = "127.0.0.1";
          grpc_listen_port = svc.loki.grpcPort;
          log_level = "warn";
        };

        common = {
          path_prefix = dataDir;
          replication_factor = 1;
          instance_addr = "127.0.0.1";
          ring.kvstore.store = "inmemory";
          storage.filesystem = {
            chunks_directory = "${dataDir}/chunks";
            rules_directory = "${dataDir}/rules";
          };
        };

        schema_config.configs = [
          {
            from = "2025-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        # the compactor is what enforces retention
        compactor = {
          working_directory = "${dataDir}/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };

        limits_config = {
          retention_period = svc.loki.retention;
          # log volume histogram in grafana explore
          volume_enabled = true;
        };
      };
    };
  };
}
