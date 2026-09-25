# boots vm.nix and walks the paths a deploy has to survive: every unit up,
# a sign-up through caddy and the gateway, and the logs landing in loki
{
  pkgs,
  module,
}:
pkgs.testers.runNixOSTest {
  name = "nagomi";
  nodes.machine.imports = [module ./vm.nix];

  testScript = ''
    start_all()

    for unit in [
        "nagomi-core", "nagomi-gateway", "nagomi-web", "nagomi-receipts",
        "nagomi-email-parser", "nagomi-connector", "loki", "alloy", "grafana", "caddy",
    ]:
        machine.wait_for_unit(f"{unit}.service")

    machine.wait_until_succeeds("curl -sf http://api.nagomi.localhost:8080/api/auth/ok")
    machine.wait_until_succeeds("curl -sf -o /dev/null http://nagomi.localhost:8080/")

    # the same requests the browser makes, cross-origin through caddy, and the
    # session cookie has to survive the round trip
    machine.succeed(
        "curl -sf -c jar -X POST http://api.nagomi.localhost:8080/api/auth/sign-up/email"
        " -H 'content-type: application/json' -H 'origin: http://nagomi.localhost:8080'"
        " -d '{\"email\":\"test@nagomi.lab\",\"password\":\"hunter2hunter2\",\"name\":\"test\"}'"
        " | jq -e .user.id"
    )
    machine.succeed(
        "curl -sf -b jar http://api.nagomi.localhost:8080/api/auth/get-session"
        " -H 'origin: http://nagomi.localhost:8080' | jq -e .user.id"
    )

    # alloy shipped the slice to loki with service and level labels
    machine.wait_until_succeeds(
        "curl -sf http://127.0.0.1:55591/loki/api/v1/label/service/values | jq -e '.data | index(\"core\") and index(\"gateway\")'"
    )
    machine.wait_until_succeeds(
        "curl -sf http://127.0.0.1:55591/loki/api/v1/label/level/values | jq -e '.data | index(\"info\")'"
    )
    machine.wait_until_succeeds(
        "curl -sf -u admin:nagomi http://127.0.0.1:55590/api/dashboards/uid/nagomi-logs | jq -e .meta.provisioned"
    )
  '';
}
