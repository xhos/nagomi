{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nagomi-core.url = "github:xhos/nagomi-core";
    nagomi-core.inputs.nixpkgs.follows = "nixpkgs";

    nagomi-gateway.url = "github:xhos/nagomi-gateway";
    nagomi-gateway.inputs.nixpkgs.follows = "nixpkgs";

    nagomi-web.url = "github:xhos/nagomi-web";
    nagomi-web.inputs.nixpkgs.follows = "nixpkgs";

    nagomi-receipts.url = "github:xhos/nagomi-receipts";
    nagomi-receipts.inputs.nixpkgs.follows = "nixpkgs";

    nagomi-statements.url = "github:xhos/nagomi-statements";
    nagomi-statements.inputs.nixpkgs.follows = "nixpkgs";

    nagomi-email-parser.url = "github:xhos/nagomi-email-parser";
    nagomi-email-parser.inputs.nixpkgs.follows = "nixpkgs";

    nagomi-connector.url = "github:xhos/nagomi-connector";
    nagomi-connector.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    system = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    vm = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
        inputs.self.nixosModules.default
        ./vm.nix
      ];
    };
  in {
    nixosModules.default = {
      lib,
      pkgs,
      ...
    }: {
      imports = [./modules];

      services.nagomi =
        lib.mapAttrs (_: input: {
          package = lib.mkDefault input.packages.${pkgs.stdenv.hostPlatform.system}.default;
        }) {
          core = inputs.nagomi-core;
          gateway = inputs.nagomi-gateway;
          web = inputs.nagomi-web;
          receipts = inputs.nagomi-receipts;
          statements = inputs.nagomi-statements;
          emailParser = inputs.nagomi-email-parser;
          connector = inputs.nagomi-connector;
        };
    };

    # prod-like stack in a vm: `nix run .#vm`, see vm.nix for the urls
    packages.${system}.vm = vm.config.system.build.vm;
    apps.${system}.vm = {
      type = "app";
      program = "${vm.config.system.build.vm}/bin/run-nagomi-vm";
    };

    checks.${system}.stack = import ./test.nix {
      inherit pkgs;
      module = inputs.self.nixosModules.default;
    };
  };
}
