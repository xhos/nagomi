{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.connector;
  nagomi = import ./lib.nix {inherit config lib;};
  inherit (lib) mkIf mkEnableOption;
in {
  options.services.nagomi.connector =
    nagomi.serviceOptions "connector" 55558
    // {
      enable = mkEnableOption "external account sync (wise, snaptrade)" // {default = true;};
    };

  config = mkIf (cfg.enable && svc.enable) {
    # snaptrade app credentials (SNAPTRADE_CLIENT_ID / SNAPTRADE_CONSUMER_KEY)
    # go in the service's secretsFile; wise needs nothing beyond the per-user token
    services.nagomi.connector.environment = nagomi.mkEnv {
      GRPC_PORT = "127.0.0.1:${toString svc.port}";
      LOG_LEVEL = cfg.logLevel;
      LOG_FORMAT = cfg.logFormat;
      NAGOMI_CORE_URL = "127.0.0.1:${toString cfg.core.port}";
    };

    systemd.services.nagomi-connector = nagomi.mkService "connector" {
      inherit (svc) environment secretsFile;
      description = "external account sync";
      exe = lib.getExe' svc.package "server";
      requires = ["nagomi-core.service"];
    };
  };
}
