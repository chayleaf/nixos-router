{
  description = "A router framework for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forEachSystem = func: nixpkgs.lib.genAttrs [ "aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux" ] (system: func {
        inherit system;
        pkgs = import nixpkgs { inherit system; };
      });
    in
    rec {
      # the format isn't the regular "lib" format, so this is marked "non-standard"
      # you have to pass config, lib and utils from NixOS module system to it
      # this is unsupported, but might be still useful overall
      nonStandardLib = import ./lib.nix;
      # this is the standard library for dealing with ip addresses
      lib = forEachSystem ({ ... }: nonStandardLib { inherit (nixpkgs) lib; });
      nixosModules.default = import ./.;
      checks.x86_64-linux.default = let pkgs = nixpkgs.legacyPackages.x86_64-linux; in pkgs.callPackage ./checks.nix {
        inherit nixpkgs;
      };
    };
}
