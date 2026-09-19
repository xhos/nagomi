{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.gateway;
  nagomi = import ./lib.nix {inherit config lib;};
  inherit (lib) types mkIf mkOption optionalAttrs concatStringsSep;
in {
  options.services.nagomi.gateway =
    nagomi.serviceOptions "gateway" 55550
    // {
      url = mkOption {
        type = types.str;
        example = "https://api.finances.example.com";
        description = "public URL of the gateway";
      };

      trustedOrigins = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["https://finances.example.com"];
        description = "CORS allowed origins";
      };

      cookieDomain = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = ".example.com";
        description = "cookie domain for cross-subdomain sessions";
      };

      secretsFile = mkOption {
        type = types.path;
        example = "/run/secrets/nagomi-gateway";
        description = "environment file providing BETTER_AUTH_SECRET";
      };
    };

  config = mkIf cfg.enable {
    services.nagomi.gateway.environment = nagomi.mkEnv ({
        HOSTNAME = "127.0.0.1";
        PORT = toString svc.port;
        LOG_LEVEL = cfg.logLevel;
        LOG_FORMAT = cfg.logFormat;
        AUTH_DATABASE_URL = "postgresql:///nagomi_auth?host=/run/postgresql";
        BETTER_AUTH_URL = svc.url;
        NAGOMI_CORE_URL = "http://127.0.0.1:${toString cfg.core.port}";
        TRUSTED_ORIGINS = concatStringsSep "," svc.trustedOrigins;
      }
      // optionalAttrs (svc.cookieDomain != null) {
        COOKIE_DOMAIN = svc.cookieDomain;
      });

    systemd.services.nagomi-gateway = nagomi.mkService "gateway" {
      inherit (svc) environment secretsFile;
      description = "auth gateway";
      exe = lib.getExe' svc.package "nagomi-gateway";
      requires = ["nagomi-db-setup.service" "nagomi-core.service"];
    };
  };
}
