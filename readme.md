# nagomi

NixOS module for the nagomi finance tracker. Runs core, gateway, web, receipts,
email-parser, postgres and a garage object store on one host, all as the
`nagomi` user under `/var/lib/nagomi/<service>`.

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
  };
}
```

Every service binds to `127.0.0.1` on its `port` option; put a reverse proxy in
front of `web.port` and `gateway.port`. Anything the module puts in a service's
environment can be overridden through its `environment` option. Databases and
the bucket are created on boot; core and gateway run their own migrations.

The `update flake input` workflow is dispatched by each `nagomi-*` repo's CI
after a green build, bumps the lockfile, and triggers the deploy in `xhos/nix`.
