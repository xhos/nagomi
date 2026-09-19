{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.web;
  nagomi = import ./lib.nix {inherit config lib;};
in {
  options.services.nagomi.web = nagomi.serviceOptions "web" 55554;

  config = lib.mkIf cfg.enable {
    services.nagomi.web.environment = nagomi.mkEnv {
      HOSTNAME = "127.0.0.1";
      PORT = toString svc.port;
      NEXT_PUBLIC_GATEWAY_URL = cfg.gateway.url;
      NEXT_TELEMETRY_DISABLED = "1";
    };

    systemd.services.nagomi-web = nagomi.mkService "web" {
      inherit (svc) environment secretsFile;
      description = "web frontend";
      exe = lib.getExe' svc.package "nagomi-web";
      requires = ["nagomi-gateway.service"];
    };
  };
}
