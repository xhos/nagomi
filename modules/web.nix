{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svcCfg = cfg.web;

  mkEnvFiles = svcSecretsFile:
    builtins.filter (f: f != null) [cfg.secretsFile svcSecretsFile];

  inherit (lib) types mkIf mkOption;
in {
  options.services.nagomi.web = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "enable web frontend";
    };

    package = mkOption {
      type = types.package;
      description = "the nagomi-web package to use";
    };

    port = mkOption {
      type = types.port;
      default = 55554;
      description = "listen port";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "bind address";
    };

    environment = mkOption {
      type = types.submodule {freeformType = types.attrsOf types.str;};
      default = {};
      description = "extra environment variables for nagomi-web";
    };

    secretsFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "web-specific secrets file";
    };
  };

  config = mkIf (cfg.enable && svcCfg.enable) {
    services.nagomi.web.environment = {
      NEXT_PUBLIC_GATEWAY_URL = cfg.gateway.url;
      HOSTNAME = svcCfg.hostname;
      PORT = toString svcCfg.port;
      NEXT_TELEMETRY_DISABLED = "1";
    };

    systemd.services.nagomi-web = {
      description = "nagomi: web frontend";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "nagomi-gateway.service"];
      requires = ["nagomi-gateway.service"];
      inherit (svcCfg) environment;
      serviceConfig =
        (import ./hardening.nix)
        // {
          ExecStart = "${svcCfg.package}/bin/nagomi-web";
          EnvironmentFile = mkEnvFiles svcCfg.secretsFile;
          Slice = "system-nagomi.slice";
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = "null-web";
          WorkingDirectory = "/var/lib/null-web";
          ReadWritePaths = ["/var/lib/null-web"];
        };
    };
  };
}
