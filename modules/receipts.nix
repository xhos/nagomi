{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.receipts;
  nagomi = import ./lib.nix {inherit config lib;};
  inherit (lib) types mkIf mkOption mkEnableOption;
in {
  options.services.nagomi.receipts =
    nagomi.serviceOptions "receipts" 55556
    // {
      enable = mkEnableOption "receipt OCR" // {default = true;};

      baseUrl = mkOption {
        type = types.str;
        default = "http://127.0.0.1:11434/v1";
        example = "https://generativelanguage.googleapis.com/v1beta/openai";
        description = "OpenAI-compatible API base URL; hosted APIs need OPENAI_API_KEY in a secrets file";
      };

      model = mkOption {
        type = types.str;
        default = "qwen2.5vl:3b";
        example = "gemini-2.5-flash";
        description = "vision model";
      };
    };

  config = mkIf (cfg.enable && svc.enable) {
    services.nagomi.receipts.environment = nagomi.mkEnv {
      LISTEN_ADDRESS = "127.0.0.1:${toString svc.port}";
      LOG_LEVEL = cfg.logLevel;
      LOG_FORMAT = cfg.logFormat;
      OPENAI_BASE_URL = svc.baseUrl;
      OPENAI_MODEL = svc.model;
    };

    systemd.services.nagomi-receipts = nagomi.mkService "receipts" {
      inherit (svc) environment secretsFile;
      description = "receipt OCR";
      exe = lib.getExe' svc.package "server";
    };
  };
}
