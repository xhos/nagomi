{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.monitoring;
in {
  config = lib.mkIf (cfg.enable && svc.enable) {
    services.alloy = {
      enable = true;
      extraFlags = ["--disable-reporting"];
    };

    # /etc/alloy is a directory so the unit can reload on config change
    environment.etc."alloy/nagomi.alloy".text = ''
      // every nagomi unit runs in system-nagomi.slice, so the slice is the
      // whole selection rule: services, setup oneshots, and anything added later
      loki.source.journal "nagomi" {
        max_age       = "24h"
        matches       = "_SYSTEMD_SLICE=system-nagomi.slice"
        labels        = {job = "nagomi"}
        relabel_rules = loki.relabel.nagomi.rules
        forward_to    = [loki.process.nagomi.receiver]
      }

      // nagomi-core.service -> service="core"
      loki.relabel "nagomi" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          regex         = "nagomi-(.+)\\.service"
          target_label  = "service"
        }
      }

      // services log json with a top-level "level"; lines that are not json
      // (stack traces, next.js) pass through without the label
      loki.process "nagomi" {
        forward_to = [loki.write.nagomi.receiver]

        stage.json {
          expressions = {level = ""}
        }

        stage.labels {
          values = {level = ""}
        }
      }

      loki.write "nagomi" {
        endpoint {
          url = "http://127.0.0.1:${toString svc.loki.port}/loki/api/v1/push"
        }
      }
    '';
  };
}
