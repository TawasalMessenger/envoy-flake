{
  description = "Envoy flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/5af1fcb77a737c86eb283ac25c7007dc4f1eb005";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    src = {
      url = "github:envoyproxy/envoy/v1.17.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-compat, src }:
    let
      sources = with builtins; (fromJSON (readFile ./flake.lock)).nodes;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      envoy = import ./build.nix {
        inherit pkgs src;
        version = sources.src.original.ref;
      };
      mkApp = drv: {
        type = "app";
        program = "${drv.pname or drv.name}${drv.passthru.exePath}";
      };
      derivation = { inherit envoy; };
    in
    rec {
      packages.${system} = derivation;
      defaultPackage.${system} = envoy;
      apps.${system}.envoy = mkApp { drv = envoy; };
      defaultApp.${system} = apps.envoy;
      legacyPackages.${system} = pkgs.extend overlay;
      devShell.${system} = pkgs.callPackage ./shell.nix derivation;
      nixosModule = {
        imports = [
          ./configuration.nix
        ];
        nixpkgs.overlays = [ overlay ];
        services.envoy.package = envoy;
      };
      overlay = final: prev: derivation;
    };
}
