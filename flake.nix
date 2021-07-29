{
  description = "Envoy flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
    flake-utils.url = "github:numtide/flake-utils";
    src = {
      url = "github:envoyproxy/envoy/v1.19.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, src }:
    let
      sources = with builtins; (fromJSON (readFile ./flake.lock)).nodes;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      envoy = import ./build.nix {
        inherit pkgs src;
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
