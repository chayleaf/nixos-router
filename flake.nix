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
    {
      # This is the standard library for dealing with ip addresses.
      # Changes to it aren't considered breaking, but of course I won't
      # change it for no reason.
      lib = forEachSystem ({ ... }: import ./lib.nix { inherit (nixpkgs) lib; });
      nixosModules.default = import ./.;
      checks.x86_64-linux.default = let pkgs = nixpkgs.legacyPackages.x86_64-linux; in pkgs.callPackage ./checks.nix {
        inherit nixpkgs;
      };
    };
}
