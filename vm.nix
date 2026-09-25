# prod-like stack for local use: the same module enrai runs, in a qemu vm,
# with caddy in front like on the host. everything is reachable from the
# host on port 8080 through *.nagomi.localhost, which browsers resolve to
# loopback without dns:
#
#   http://nagomi.localhost:8080          web
#   http://api.nagomi.localhost:8080      gateway
#   http://monitor.nagomi.localhost:8080  grafana (admin / nagomi)
#   smtp 127.0.0.1:2525                   email parser
#
# secrets are dev values baked into the store; never reuse them anywhere
{
  config,
  pkgs,
  ...
}: let
  domain = "nagomi.localhost";
  port = 8080;
  cfg = config.services.nagomi;
  hosts = [domain "api.${domain}" "monitor.${domain}"];

  secrets = name: text: pkgs.writeText "nagomi-vm-${name}" text;
in {
  networking.hostName = "nagomi";
  system.stateVersion = "25.05";

  services.nagomi = {
    enable = true;
    logLevel = "debug";

    secretsFile = secrets "shared" ''
      API_KEY=dev-local-api-key
      S3_ACCESS_KEY=GKdeadbeefcafe0000deadbeef
      S3_SECRET_KEY=deadbeefcafe0000deadbeefcafe0000deadbeefcafe0000deadbeefcafe0000
      GARAGE_RPC_SECRET=0000000000000000000000000000000000000000000000000000000000000000
    '';
    core.secretsFile = secrets "core" ''
      CREDENTIALS_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
    '';
    gateway.secretsFile = secrets "gateway" ''
      BETTER_AUTH_SECRET=dev-local-better-auth-secret-min32chars-not-for-prod
    '';
    monitoring.secretsFile = secrets "monitoring" ''
      GF_SECURITY_ADMIN_PASSWORD=nagomi
      GF_SECURITY_SECRET_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
    '';

    gateway.url = "http://api.${domain}:${toString port}";
    gateway.trustedOrigins = ["http://${domain}:${toString port}"];
    gateway.cookieDomain = ".${domain}";

    emailParser.enable = true;
    emailParser.domain = "mail.${domain}";
    emailParser.smtpAddress = "0.0.0.0";

    monitoring.enable = true;
    monitoring.url = "http://monitor.${domain}:${toString port}";
  };

  # one vhost per exposed service, as the homelab caddy does
  services.caddy = {
    enable = true;
    virtualHosts = let
      vhost = name: upstream: {
        name = "http://${name}:${toString port}";
        value.extraConfig = "reverse_proxy 127.0.0.1:${toString upstream}";
      };
    in
      builtins.listToAttrs [
        (vhost domain cfg.web.port)
        (vhost "api.${domain}" cfg.gateway.port)
        (vhost "monitor.${domain}" cfg.monitoring.port)
      ];
  };

  # so the names work inside the guest too (tests, curl from the console)
  networking.hosts."127.0.0.1" = hosts;
  networking.firewall.allowedTCPPorts = [port cfg.emailParser.smtpPort];

  virtualisation = {
    memorySize = 3072;
    cores = 4;
    graphics = false;
    forwardPorts = [
      {
        from = "host";
        host.port = port;
        guest.port = port;
      }
      {
        from = "host";
        host.port = cfg.emailParser.smtpPort;
        guest.port = cfg.emailParser.smtpPort;
      }
    ];
  };

  services.getty.autologinUser = "root";
  environment.systemPackages = [pkgs.curl pkgs.jq];
}
