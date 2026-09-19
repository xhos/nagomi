# helpers shared by the per-service modules
{
  config,
  lib,
}: let
  cfg = config.services.nagomi;
  inherit (lib) types mkOption mkDefault mapAttrs optional;

  hardening = {
    Restart = "on-failure";
    RestartSec = 3;

    CapabilityBoundingSet = "";
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateMounts = true;
    PrivateTmp = true;
    PrivateUsers = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    UMask = "0077";
  };
in rec {
  # options every service declares
  serviceOptions = name: port: {
    package = mkOption {
      type = types.package;
      description = "nagomi-${name} package";
    };

    port = mkOption {
      type = types.port;
      default = port;
      description = "listen port, bound to 127.0.0.1";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "environment for nagomi-${name}, overrides what the module sets";
    };

    secretsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "environment file loaded after services.nagomi.secretsFile";
    };
  };

  # environment the module sets; anything in the service's `environment` wins
  mkEnv = mapAttrs (_: mkDefault);

  # a hardened unit running as nagomi with its own state directory
  mkService = name: {
    description,
    exe,
    requires ? [],
    environment ? {},
    secretsFile ? null,
  }: {
    description = "nagomi ${description}";
    wantedBy = ["multi-user.target"];
    inherit requires environment;
    after = ["network.target"] ++ requires;
    serviceConfig =
      hardening
      // {
        ExecStart = exe;
        EnvironmentFile = [cfg.secretsFile] ++ optional (secretsFile != null) secretsFile;
        User = "nagomi";
        Group = "nagomi";
        Slice = "system-nagomi.slice";
        StateDirectory = "nagomi/${name}";
        WorkingDirectory = "/var/lib/nagomi/${name}";
      };
  };
}
