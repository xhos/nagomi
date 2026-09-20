{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  inherit (lib) types mkIf mkOption mkEnableOption;
in {
  imports = [
    ./database.nix
    ./storage.nix
    ./core.nix
    ./gateway.nix
    ./web.nix
    ./receipts.nix
    ./email-parser.nix
    ./monitoring
  ];

  options.services.nagomi = {
    enable = mkEnableOption "nagomi finance tracker";

    secretsFile = mkOption {
      type = types.path;
      example = "/run/secrets/nagomi";
      description = ''
        environment file loaded by every service. must provide API_KEY,
        S3_ACCESS_KEY, S3_SECRET_KEY and GARAGE_RPC_SECRET. per-service
        `secretsFile` options are loaded after it.
      '';
    };

    logLevel = mkOption {
      type = types.enum ["debug" "info" "warn" "error"];
      default = "info";
      description = "log level for all services";
    };

    logFormat = mkOption {
      type = types.enum ["text" "json"];
      default = "json";
      description = "log format for all services";
    };
  };

  config = mkIf cfg.enable {
    users.users.nagomi = {
      isSystemUser = true;
      group = "nagomi";
      home = "/var/lib/nagomi";
    };
    users.groups.nagomi = {};

    # each service gets its own StateDirectory=nagomi/<name> underneath
    systemd.tmpfiles.settings.nagomi."/var/lib/nagomi".d = {
      user = "nagomi";
      group = "nagomi";
      mode = "0750";
    };

    systemd.slices.system-nagomi.description = "nagomi finance tracker";
  };
}
