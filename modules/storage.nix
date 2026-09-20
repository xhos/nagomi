{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.nagomi;
  svc = cfg.storage;
  nagomi = import ./lib.nix {inherit config lib;};
  inherit (lib) types mkIf mkOption;

  stateDir = "/var/lib/nagomi/garage";
  garage = "${lib.getExe svc.package} -c ${garageConfig}";
  garageConfig = pkgs.writeText "nagomi-garage.toml" ''
    metadata_dir = "${stateDir}/meta"
    data_dir = "${stateDir}/data"
    db_engine = "sqlite"
    replication_factor = 1
    rpc_bind_addr = "127.0.0.1:${toString svc.rpcPort}"
    rpc_public_addr = "127.0.0.1:${toString svc.rpcPort}"

    [s3_api]
    api_bind_addr = "127.0.0.1:${toString svc.s3Port}"
    s3_region = "${svc.region}"
    root_domain = ".s3.local"

    [admin]
    api_bind_addr = "127.0.0.1:${toString svc.adminPort}"
  '';
in {
  options.services.nagomi.storage = {
    package = mkOption {
      type = types.package;
      default = pkgs.garage;
      description = "garage package";
    };

    s3Port = mkOption {
      type = types.port;
      default = 55580;
      description = "S3 API port";
    };

    rpcPort = mkOption {
      type = types.port;
      default = 55581;
      description = "cluster RPC port";
    };

    adminPort = mkOption {
      type = types.port;
      default = 55582;
      description = "admin API port";
    };

    region = mkOption {
      type = types.str;
      default = "garage";
      description = "S3 region name";
    };

    bucket = mkOption {
      type = types.str;
      default = "nagomi";
      description = "bucket holding receipt blobs";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.nagomi-garage = nagomi.mkService "garage" {
      description = "object store";
      exe = "${garage} server";
    };

    # layout, key and bucket creation; every step is idempotent
    systemd.services.nagomi-storage-setup = {
      description = "nagomi object store setup";
      wantedBy = ["multi-user.target"];
      requires = ["nagomi-garage.service"];
      after = ["nagomi-garage.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "nagomi";
        Group = "nagomi";
        EnvironmentFile = [cfg.secretsFile];
        Slice = "system-nagomi.slice";
      };
      script = ''
        for _ in $(seq 60); do
          ${garage} status >/dev/null 2>&1 && break
          sleep 1
        done

        node=$(${garage} node id -q | cut -d@ -f1)
        if ! ${garage} layout show 2>&1 | grep -q "$node"; then
          ${garage} layout assign -z dc1 -c 1G "$node"
          version=$(${garage} layout show 2>&1 | sed -n 's/.*layout version: //p' | head -1)
          ${garage} layout apply --version $((version + 1))
        fi

        ${garage} key import --yes -n nagomi "$S3_ACCESS_KEY" "$S3_SECRET_KEY" 2>&1 | grep -v "already exists" || true
        ${garage} bucket create ${svc.bucket} 2>&1 | grep -v "already exists" || true
        ${garage} bucket allow --read --write --owner --key nagomi ${svc.bucket}
      '';
    };
  };
}
