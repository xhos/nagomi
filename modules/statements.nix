{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.statements;
  nagomi = import ./lib.nix {inherit config lib;};
  inherit (lib) mkIf mkEnableOption;
in {
  options.services.nagomi.statements =
    nagomi.serviceOptions "statements" 55559
    // {
      enable = mkEnableOption "bank statement parsing" // {default = true;};
    };

  config = mkIf (cfg.enable && svc.enable) {
    services.nagomi.statements.environment = nagomi.mkEnv {
      LISTEN_ADDRESS = "127.0.0.1:${toString svc.port}";
      LOG_LEVEL = cfg.logLevel;
      LOG_FORMAT = cfg.logFormat;
    };

    systemd.services.nagomi-statements = nagomi.mkService "statements" {
      inherit (svc) environment secretsFile;
      description = "statement parser";
      exe = lib.getExe svc.package;
    };
  };
}
