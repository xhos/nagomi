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

    nagomi-email-parser.url = "github:xhos/nagomi-email-parser";
    nagomi-email-parser.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: {
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
          emailParser = inputs.nagomi-email-parser;
        };
    };
  };
}
