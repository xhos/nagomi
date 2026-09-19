{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.receipts;
  nagomi = import ./lib.nix {inherit config lib;};
  inherit (lib) types mkIf mkOption mkEnableOption optionalAttrs;
in {
  options.services.nagomi.receipts =
    nagomi.serviceOptions "receipts" 55556
    // {
      enable = mkEnableOption "receipt OCR" // {default = true;};

      provider = mkOption {
        type = types.enum ["ollama" "gemini"];
        default = "ollama";
        description = "vision model provider; gemini needs GOOGLE_API_KEY in a secrets file";
      };

      ollama = {
        host = mkOption {
          type = types.str;
          default = "http://127.0.0.1:11434";
          description = "ollama API endpoint";
        };
        model = mkOption {
          type = types.str;
          default = "qwen2.5vl:3b";
          description = "ollama model";
        };
      };

      gemini.model = mkOption {
        type = types.str;
        default = "gemini-2.0-flash";
        description = "gemini model";
      };
    };

  config = mkIf (cfg.enable && svc.enable) {
    services.nagomi.receipts.environment = nagomi.mkEnv ({
        LISTEN_ADDRESS = "127.0.0.1:${toString svc.port}";
        LOG_LEVEL = cfg.logLevel;
        LOG_FORMAT = cfg.logFormat;
        PROVIDER = svc.provider;
      }
      // optionalAttrs (svc.provider == "ollama") {
        OLLAMA_HOST = svc.ollama.host;
        OLLAMA_MODEL = svc.ollama.model;
      }
      // optionalAttrs (svc.provider == "gemini") {
        GEMINI_MODEL = svc.gemini.model;
      });

    systemd.services.nagomi-receipts = nagomi.mkService "receipts" {
      inherit (svc) environment secretsFile;
      description = "receipt OCR";
      exe = lib.getExe' svc.package "server";
    };
  };
}
