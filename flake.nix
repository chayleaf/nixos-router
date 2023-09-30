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
      # This is the standard library for dealing with ip addresses.
      # Changes to it aren't considered breaking, but of course I won't
      # change it for no reason.
      lib = forEachSystem ({ ... }: import ./lib.nix { inherit (nixpkgs) lib; });
      nixosModules.default = import ./.;
      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixpkgs-fmt);
      checks.x86_64-linux.default = let pkgs = nixpkgs.legacyPackages.x86_64-linux; in pkgs.callPackage ./checks.nix {
        inherit nixpkgs;
      };
      apps = forEachSystem (
        ({ pkgs, system, ... }: {
          make-docs =
            let
              eval = import (pkgs.path + "/nixos/lib/eval-config.nix") {
                inherit system;
                modules = [
                  ./default.nix
                ];
              };
            in
            {
              type = "app";
              program = toString (pkgs.writers.writeBash "debug-router" ''
                cp "${(pkgs.nixosOptionsDoc {
                  options = eval.options.router;
                  transformOptions = opt: opt // (with nixpkgs.lib; {
                    declarations = map (decl: if hasPrefix (toString ./.) (toString decl) then
                      let
                        subpath = removePrefix "/" (removePrefix (toString ./.) (toString decl));
                      in {
                        url = "${subpath}"; name = subpath;
                      } else decl) opt.declarations;
                  });
                }).optionsCommonMark}" OPTIONS.md
                  chmod 644 OPTIONS.md
              '');
            };
        })
      );
    };
}
