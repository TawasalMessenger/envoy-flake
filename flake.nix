{
  description = "Envoy flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs_go.url = "github:NixOS/nixpkgs/fc7bd322dfcd204ce6daa95285ff358999ff9a8d"; # https://github.com/envoyproxy/envoy/pull/16083
    flake-utils.url = "github:numtide/flake-utils";
    src = {
      url = "github:envoyproxy/envoy/v1.18.3";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs_go, flake-utils, src }:
    let
      sources = with builtins; (fromJSON (readFile ./flake.lock)).nodes;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      go_1_15 = nixpkgs_go.legacyPackages.${system}.go_1_15;
      envoy = import ./build.nix {
        inherit pkgs go_1_15 src;
        version = sources.src.original.ref;
      };
      envoy-app = flake-utils.lib.mkApp { drv = envoy; };
      derivation = { inherit envoy; };
    in
    with pkgs; rec {
      packages.${system} = derivation;
      defaultPackage.${system} = envoy;
      apps.${system}.envoy = envoy-app;
      defaultApp.${system} = envoy-app;
      legacyPackages.${system} = extend overlay;
      devShell.${system} = callPackage ./shell.nix derivation;
      nixosModule = {
        imports = [
          ./configuration.nix
        ];
        nixpkgs.overlays = [ overlay ];
        services.envoy.package = lib.mkDefault envoy;
      };
      overlay = final: prev: derivation;
    };
}
