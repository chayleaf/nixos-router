{ nixpkgs }:

let
  inherit (nixpkgs) lib;
  inherit
    (lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        (import ./.)
        {
          system.stateVersion = "23.05";
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
            neededForBoot = false;
            options = [
              "defaults"
              "size=2G"
              "mode=755"
            ];
          };
          boot.loader.grub.device = "nodev";
          router.enable = true;
          router.interfaces.br0 = {
            ipv4.kea.enable = true;
            ipv6.corerad.enable = true;
            ipv6.kea.enable = true;
            ipv4.addresses = [
              {
                address = "192.168.1.1";
                prefixLength = 24;
              }
            ];
            ipv6.enableForwarding = true;
          };
          networking.nftables.enable = true;
        }
      ];
    })
    config
    ;
  drv = config.system.build.toplevel;

  eq = a: b: lib.assertMsg (a == b) "Expected ${builtins.toJSON a} == ${builtins.toJSON b}";
  matches = r: s: lib.assertMsg (builtins.match r s != null) "Expected ${s} to match ${r}";
  notMatches = r: s: lib.assertMsg (builtins.match r s == null) "Expected ${s} not to match ${r}";
  backtrip =
    func1: func2: a: b:
    assert eq (func1 a) b;
    eq (func2 b) a;

  router-lib = import ./lib.nix {
    inherit lib config;
  };
  inherit (router-lib)
    parseIp
    serializeIp
    invMask
    ip4Regex
    ip6Regex
    ;
  backtripIp =
    a: b:
    assert matches (if lib.hasInfix ":" a then ip6Regex else ip4Regex) a;
    backtrip parseIp serializeIp a b;
in

assert backtripIp "0.0.0.0" [
  0
  0
  0
  0
];
assert backtripIp "127.0.0.1" [
  127
  0
  0
  1
];
assert backtripIp "255.255.255.255" [
  255
  255
  255
  255
];
assert backtripIp "::" [
  0
  0
  0
  0
  0
  0
  0
  0
];
assert backtripIp "a::" [
  10
  0
  0
  0
  0
  0
  0
  0
];
assert backtripIp "::a" [
  0
  0
  0
  0
  0
  0
  0
  10
];
assert backtripIp "a:a:a:a:a:a:a:a" [
  10
  10
  10
  10
  10
  10
  10
  10
];
assert backtripIp "ffff::ffff" [
  65535
  0
  0
  0
  0
  0
  0
  65535
];
assert backtripIp "ffff:ffff:ffff::ffff" [
  65535
  65535
  65535
  0
  0
  0
  0
  65535
];
assert backtripIp "ffff:ffff:ffff:ffff:ffff:ffff:ffff::" [
  65535
  65535
  65535
  65535
  65535
  65535
  65535
  0
];
assert backtripIp "ffff::ffff:ffff:ffff" [
  65535
  0
  0
  0
  0
  65535
  65535
  65535
];
assert eq
  (invMask [
    255
    128
    0
    0
  ])
  [
    0
    127
    255
    255
  ];
assert eq
  (invMask [
    65535
    32768
    0
    0
    0
    0
    0
    0
  ])
  [
    0
    32767
    65535
    65535
    65535
    65535
    65535
    65535
  ];
assert matches ip4Regex "0.0.9.255";
assert matches ip4Regex "255.249.199.99";
assert notMatches ip4Regex "0.0.00";
assert notMatches ip4Regex "0.0.0.0.";
assert notMatches ip4Regex "0.0.0..";
assert notMatches ip4Regex "0.0.00.0";
assert notMatches ip4Regex "0.0..0";
assert notMatches ip4Regex "0.0..0.0";
assert notMatches ip4Regex "0.0.0.300";
assert notMatches ip4Regex "0.0.0.256";
assert notMatches ip4Regex "0.0.0.260";
assert notMatches ip6Regex "::fffg";
assert notMatches ip6Regex "::fffff";
assert notMatches ip6Regex ":f:";
assert notMatches ip6Regex "f:f:f:f:f:f:f:f:";
assert notMatches ip6Regex "f:f:f:f:f:f:f:f:f";

builtins.trace drv.outPath drv
