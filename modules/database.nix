{
  config,
  lib,
  ...
}: let
  cfg = config.services.nagomi;
in {
  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      ensureDatabases = ["nagomi" "nagomi_auth"];
      ensureUsers = [{name = "nagomi";}];
    };

    # ensureDatabases creates them owned by postgres; hand them to the nagomi
    # role so core and gateway can run their own migrations on boot
    systemd.services.nagomi-db-setup = {
      description = "nagomi database ownership";
      requires = ["postgresql-setup.service"];
      after = ["postgresql-setup.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        Group = "postgres";
        Slice = "system-nagomi.slice";
      };
      script = let
        psql = lib.getExe' config.services.postgresql.package "psql";
      in ''
        ${psql} -tAc 'ALTER DATABASE "nagomi" OWNER TO "nagomi"'
        ${psql} -tAc 'ALTER DATABASE "nagomi_auth" OWNER TO "nagomi"'
      '';
    };
  };
}
