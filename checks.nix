{ nixpkgs }:

let
  inherit (nixpkgs) lib;
  drv = (lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      (import ./.)
      {
        system.stateVersion = "23.05";
        fileSystems."/" = { device = "none"; fsType = "tmpfs"; neededForBoot = false; options = [ "defaults" "size=2G" "mode=755" ]; };
        boot.loader.grub.device = "nodev";
        router.enable = true;
        networking.nftables.enable = true;
      }
    ];
  }).config.system.build.toplevel;
in
  builtins.trace drv.outPath drv
