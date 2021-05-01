{
  description = "Envoy flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    src = {
      url = "github:envoyproxy/envoy/v1.18.2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-compat, flake-utils, src }:
    let
      sources = with builtins; (fromJSON (readFile ./flake.lock)).nodes;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      envoy = import ./build.nix {
        inherit pkgs src;
        version = sources.src.original.ref;
      };
      derivation = { inherit envoy; };
    in
    with pkgs; rec {
      packages.${system} = derivation;
      defaultPackage.${system} = envoy;
      apps.${system}.envoy = flake-utils.lib.mkApp { drv = envoy; };
      defaultApp.${system} = apps.envoy;
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
