{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  inherit (lib) types mkIf mkOption mkEnableOption;
in {
  options.services.nagomi = {
    enable = mkEnableOption "nagomi finance tracker";

    # These defaults identify existing production data and Unix accounts.
    # Change them only with an explicit migration of the data on mizore.

    user = mkOption {
      type = types.str;
      default = "null";
      description = "user under which nagomi services run";
    };

    group = mkOption {
      type = types.str;
      default = "null";
      description = "group under which nagomi services run";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/null";
      description = "base data directory";
    };

    logLevel = mkOption {
      type = types.enum ["debug" "info" "warn" "error"];
      default = "info";
      description = "log level for all services";
    };

    logFormat = mkOption {
      type = types.enum ["text" "json"];
      default = "json";
      description = "log format for all services, use json for structured logging in production";
    };

    secretsFile = mkOption {
      type = types.nullOr (types.str
        // {
          check = it: lib.isString it && lib.types.path.check it;
        });
      default = null;
      example = "/run/secrets/nagomi";
      description = "shared secrets file loaded by all services as an EnvironmentFile, not added to the nix store";
    };

    database = {
      enable =
        mkEnableOption "postgresql for nagomi"
        // {
          default = true;
        };

      createDB =
        mkEnableOption "automatic database and user creation"
        // {
          default = true;
        };

      host = mkOption {
        type = types.str;
        default = "/run/postgresql";
        example = "127.0.0.1";
        description = "postgresql host, an absolute path is interpreted as a unix socket directory";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "postgresql port (ignored when using unix sockets)";
      };

      user = mkOption {
        type = types.str;
        default = "null";
        description = "postgresql user";
      };

      name = mkOption {
        type = types.str;
        default = "null";
        description = "core database name";
      };

      authName = mkOption {
        type = types.str;
        default = "null_auth";
        description = "auth database name (used by gateway / better auth)";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.database.host || cfg.secretsFile != null;
        message = "services.nagomi.secretsFile must be set with DATABASE_URL and AUTH_DATABASE_URL when not using unix sockets";
      }
      {
        assertion = !cfg.emailParser.enable || cfg.core.enable;
        message = "services.nagomi.core must be enabled when emailParser is enabled";
      }
    ];

    users.users = mkIf (cfg.user == "null") {
      "null" = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        createHome = true;
      };
    };

    users.groups = mkIf (cfg.group == "null") {"null" = {};};

    services.postgresql = mkIf cfg.database.enable {
      enable = true;
      ensureDatabases = mkIf cfg.database.createDB [
        cfg.database.name
        cfg.database.authName
      ];
      ensureUsers = mkIf cfg.database.createDB [
        {
          name = cfg.database.user;
          ensureClauses.login = true;
        }
      ];
    };

    systemd.services.nagomi-db-setup = mkIf (cfg.database.enable && cfg.database.createDB) {
      description = "nagomi: database setup";
      requires = ["postgresql.service" "postgresql-setup.service"];
      after = ["postgresql.service" "postgresql-setup.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        Group = "postgres";
      };
      script = let
        psql = lib.getExe' config.services.postgresql.package "psql";
      in ''
        ${psql} -tAc "ALTER DATABASE \"${cfg.database.name}\" OWNER TO \"${cfg.database.user}\""
        ${psql} -tAc "ALTER DATABASE \"${cfg.database.authName}\" OWNER TO \"${cfg.database.user}\""
        ${psql} -d "${cfg.database.name}" -tAc "CREATE EXTENSION IF NOT EXISTS pg_trgm"
        ${psql} -d "${cfg.database.name}" -tAc "CREATE EXTENSION IF NOT EXISTS pgcrypto"
      '';
    };

    systemd.slices.system-nagomi = {
      description = "nagomi finance tracker services";
    };

    systemd.tmpfiles.settings.nagomi = {
      "${cfg.dataDir}" = {
        d = {
          user = cfg.user;
          group = cfg.group;
          mode = "0700";
        };
      };
    };
  };
}
