# logs stack: alloy tails the journal for everything in the nagomi slice and
# ships it to loki; grafana fronts loki with a provisioned dashboard
{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.monitoring;
  inherit (lib) types mkIf mkOption mkEnableOption hasPrefix;

  dashboards = ./dashboards;
in {
  imports = [
    ./loki.nix
    ./alloy.nix
  ];

  options.services.nagomi.monitoring = {
    enable = mkEnableOption "grafana + loki log stack for nagomi";

    url = mkOption {
      type = types.str;
      example = "https://monitor.finances.example.com";
      description = "public URL of grafana";
    };

    port = mkOption {
      type = types.port;
      default = 55590;
      description = "grafana listen port, bound to 127.0.0.1";
    };

    secretsFile = mkOption {
      type = types.path;
      example = "/run/secrets/nagomi-monitoring";
      description = ''
        environment file providing GF_SECURITY_ADMIN_PASSWORD and
        GF_SECURITY_SECRET_KEY (`openssl rand -hex 32`)
      '';
    };

    loki = {
      port = mkOption {
        type = types.port;
        default = 55591;
        description = "loki HTTP port, bound to 127.0.0.1";
      };

      grpcPort = mkOption {
        type = types.port;
        default = 55592;
        description = "loki gRPC port, bound to 127.0.0.1";
      };

      retention = mkOption {
        type = types.str;
        default = "30d";
        example = "90d";
        description = "how long loki keeps log lines";
      };
    };
  };

  config = mkIf (cfg.enable && svc.enable) {
    services.grafana = {
      enable = true;

      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = svc.port;
          root_url = svc.url;
        };

        # both come from secretsFile; grafana expands $__env at startup
        security = {
          admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
          secret_key = "$__env{GF_SECURITY_SECRET_KEY}";
          cookie_secure = hasPrefix "https://" svc.url;
          disable_gravatar = true;
        };

        users.allow_sign_up = false;
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
        };
        news.news_feed_enabled = false;

        dashboards.default_home_dashboard_path = "${dashboards}/logs.json";
      };

      provision = {
        enable = true;

        datasources.settings.datasources = [
          {
            name = "Loki";
            type = "loki";
            uid = "loki";
            url = "http://127.0.0.1:${toString svc.loki.port}";
            isDefault = true;
            editable = false;
          }
        ];

        dashboards.settings.providers = [
          {
            name = "nagomi";
            options.path = dashboards;
            disableDeletion = true;
            allowUiUpdates = false;
          }
        ];
      };
    };

    systemd.services.grafana.serviceConfig.EnvironmentFile = [svc.secretsFile];
  };
}
