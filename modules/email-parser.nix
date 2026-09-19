{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.emailParser;
  nagomi = import ./lib.nix {inherit config lib;};
  inherit (lib) types mkIf mkOption mkEnableOption optionalAttrs;
in {
  options.services.nagomi.emailParser =
    nagomi.serviceOptions "email-parser" 55557
    // {
      enable = mkEnableOption "email parser SMTP ingest";

      smtpAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = "SMTP listen address; mail is forwarded in from outside, so this is usually not loopback";
      };

      smtpPort = mkOption {
        type = types.port;
        default = 2525;
        description = "SMTP listen port";
      };

      domain = mkOption {
        type = types.str;
        example = "mail.finances.example.com";
        description = "domain that receives bank notification emails";
      };

      tls = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            certFile = mkOption {
              type = types.path;
              description = "TLS certificate chain";
            };
            keyFile = mkOption {
              type = types.path;
              description = "TLS private key";
            };
          };
        });
        default = null;
        description = "STARTTLS certificate; without it the SMTP server runs in plaintext";
      };
    };

  config = mkIf (cfg.enable && svc.enable) {
    services.nagomi.emailParser.environment = nagomi.mkEnv ({
        SMTP_PORT = "${svc.smtpAddress}:${toString svc.smtpPort}";
        GRPC_PORT = "127.0.0.1:${toString svc.port}";
        LOG_LEVEL = cfg.logLevel;
        LOG_FORMAT = cfg.logFormat;
        DOMAIN = svc.domain;
        NAGOMI_CORE_URL = "127.0.0.1:${toString cfg.core.port}";
      }
      // optionalAttrs (svc.tls != null) {
        TLS_CERT = toString svc.tls.certFile;
        TLS_KEY = toString svc.tls.keyFile;
      });

    systemd.services.nagomi-email-parser = nagomi.mkService "email-parser" {
      inherit (svc) environment secretsFile;
      description = "email parser";
      exe = lib.getExe' svc.package "server";
      requires = ["nagomi-core.service"];
    };
  };
}
