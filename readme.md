# nagomi

A self-hosted personal finance tracker. This repo is the NixOS module that runs the whole stack on one host, as the `nagomi` user under `/var/lib/nagomi/<service>`, alongside postgres and garage.

## services

| repo | | port |
|---|---|---|
| [nagomi-core](https://github.com/xhos/nagomi-core) | Backend | 55555 |
| [nagomi-gateway](https://github.com/xhos/nagomi-gateway) | Auth, and the proxy clients use to reach core | 55550 |
| [nagomi-web](https://github.com/xhos/nagomi-web) | Web dashboard | 55554 |
| [nagomi-mobile](https://github.com/xhos/nagomi-mobile) | Android app | |
| [nagomi-receipts](https://github.com/xhos/nagomi-receipts) | Receipt parsing | 55556 |
| [nagomi-statements](https://github.com/xhos/nagomi-statements) | Statement parsing | 55559 |
| [nagomi-email-parser](https://github.com/xhos/nagomi-email-parser) | Bank email ingest | 55557 |
| [nagomi-connector](https://github.com/xhos/nagomi-connector) | Wise and SnapTrade sync | 55558 |
| [nagomi-mcp](https://github.com/xhos/nagomi-mcp) | MCP server. Not part of this module | 55553 |
| [nagomi-protos](https://github.com/xhos/nagomi-protos) | Shared protobuf definitions | |

## usage

```nix
{
  imports = [inputs.nagomi.nixosModules.default];

  services.nagomi = {
    enable = true;
    secretsFile = "/run/secrets/nagomi"; # API_KEY, S3_ACCESS_KEY, S3_SECRET_KEY, GARAGE_RPC_SECRET
    core.secretsFile = "/run/secrets/nagomi-core"; # CREDENTIALS_KEY
    gateway.secretsFile = "/run/secrets/nagomi-gateway"; # BETTER_AUTH_SECRET
    gateway.url = "https://api.finances.example.com";
    gateway.trustedOrigins = ["https://finances.example.com"];
    gateway.cookieDomain = ".example.com";
    receipts.provider = "gemini";
    receipts.secretsFile = "/run/secrets/nagomi-receipts"; # GOOGLE_API_KEY
    emailParser.enable = true;
    emailParser.domain = "mail.finances.example.com";
    monitoring.enable = true;
    monitoring.url = "https://monitor.finances.example.com";
    monitoring.secretsFile = "/run/secrets/nagomi-monitoring"; # GF_SECURITY_ADMIN_PASSWORD, GF_SECURITY_SECRET_KEY
  };
}
```

Receipts, statements and connector are on by default; email-parser and
monitoring are opt-in. Every service binds to `127.0.0.1` on its `port` option;
put a reverse proxy in front of `web.port` and `gateway.port`. Anything the
module puts in a service's environment can be overridden through its
`environment` option. Databases and the bucket are created on boot; core and
gateway run their own migrations.

## monitoring

`monitoring.enable` adds a logs stack: alloy tails the journal for every unit
in `system-nagomi.slice`, labels each line with its `service` and json `level`,
and ships it to loki; grafana (on `monitoring.port`, proxy it like the others)
comes with the loki datasource and a `nagomi · logs` dashboard provisioned as
the home page. Retention is `monitoring.loki.retention` (30d). State lives in
`/var/lib/loki` and `/var/lib/grafana`; the journal itself must be persistent.

## ci

The `update flake input` workflow is dispatched by each `nagomi-*` repo's CI
after a green build, bumps the lockfile, and triggers the deploy in `xhos/nix`.
