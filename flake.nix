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

  outputs = {nixpkgs, ...} @ inputs: {
    nixosModules.default = {pkgs, ...}: {
      imports = [
        ./modules/shared.nix
        ./modules/core.nix
        ./modules/gateway.nix
        ./modules/web.nix
        ./modules/receipts.nix
        ./modules/email-parser.nix
        ./modules/storage.nix
      ];

      services.nagomi.core.package = inputs.nagomi-core.packages.${pkgs.system}.default;
      services.nagomi.gateway.package = inputs.nagomi-gateway.packages.${pkgs.system}.default;
      services.nagomi.web.package = inputs.nagomi-web.packages.${pkgs.system}.default;
      services.nagomi.receipts.package = inputs.nagomi-receipts.packages.${pkgs.system}.default;
      services.nagomi.emailParser.package = inputs.nagomi-email-parser.packages.${pkgs.system}.default;
    };
  };
}
