{ lib
, config
, pkgs
, utils
, router-lib
, ... }:

let
  cfg = config.router;
  # add x to last component of a parsed ipv4
  addToLastComp4 = x: ip:
    let
      n0 = lib.last ip;
      nx = n0 + x;
      n = if nx >= 255 then 254 else if nx < 2 then 2 else nx;
    in
      if x > 0 && n0 >= 255 then null
      else if x < 0 && n0 < 2 then null
      else lib.init ip ++ [ n ];
  # add x to last component of a parsed ipv6
  addToLastComp6 = x: ip:
    let
      n0 = lib.last ip;
      nx = n0 + x;
      n = if nx >= 65535 then 65534 else if nx <= 2 then 2 else nx;
    in
      if x > 0 && n0 >= 65535 then null
      else if x < 0 && n0 < 2 then null
      else lib.init ip ++ [ n ];
  format = pkgs.formats.json {};
  package = pkgs.kea;
  commonServiceConfig = {
    ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    DynamicUser = true;
    User = "kea";
    ConfigurationDirectory = "kea";
    RuntimeDirectory = "kea";
    StateDirectory = "kea";
    UMask = "0077";
  };
in {
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (let
      configs = lib.flip builtins.mapAttrs cfg.interfaces (interface: icfg:
      let
        cfg4 = icfg.ipv4.kea;
      in if cfg4.configFile != null then cfg4.configFile else (format.generate "kea-dhcp4-${interface}.conf" {
        Dhcp4 = {
          valid-lifetime = 4000;
          interfaces-config.interfaces = [ interface ];
          lease-database = {
            type = "memfile";
            persist = true;
            name = "/var/lib/private/kea/dhcp4-${interface}.leases";
          };
          subnet4 = map ({ address, prefixLength, gateways, dns, keaSettings, ... }:
          let
            subnetMask = router-lib.genMask4 prefixLength;
            parsed = router-lib.parseIp4 address;
            minIp = router-lib.andMask subnetMask parsed;
            maxIp = router-lib.orMask (router-lib.invMask4 subnetMask) parsed;
          in {
            inherit interface;
            subnet = router-lib.serializeCidr { inherit address prefixLength; };
            option-data =
              lib.optional (dns != [ ]) {
                name = "domain-name-servers";
                code = 6;
                csv-format = true;
                space = "dhcp4";
                data = builtins.concatStringsSep ", " dns;
              }
              ++ [ {
                name = "routers";
                code = 3;
                csv-format = true;
                space = "dhcp4";
                data = builtins.concatStringsSep ", " (if gateways != null then gateways else [ address ]);
              } ];
            pools = let
              a = addToLastComp4 16 minIp;
              b = addToLastComp4 (-16) parsed;
              c = addToLastComp4 16 parsed;
              d = addToLastComp4 (-16) maxIp;
            in
              lib.optional (a != null && b != null && a <= b) {
                pool = "${router-lib.serializeIp4 a}-${router-lib.serializeIp4 b}";
              }
              ++ lib.optional (c != null && d != null && c <= d) {
                pool = "${router-lib.serializeIp4 c}-${router-lib.serializeIp4 d}";
              };
          } // keaSettings) icfg.ipv4.addresses;
        } // cfg4.settings;
      }));
    in {
      environment.etc = lib.mapAttrs' (interface: icfg: {
        name = "kea/dhcp4-server-${utils.escapeSystemdPath interface}.conf";
        value = lib.mkIf (icfg.ipv4.kea.enable && icfg.ipv4.addresses != [ ]) {
          source = configs.${interface};
        };
      }) cfg.interfaces;

      systemd.services = lib.flip lib.mapAttrs' cfg.interfaces (interface: icfg: {
        name = "kea-dhcp4-server-${utils.escapeSystemdPath interface}";
        value = lib.mkIf (icfg.ipv4.kea.enable && icfg.ipv4.addresses != [ ]) (router-lib.mkServiceForIf interface {
          description = "Kea DHCP4 Server (${interface})";
          documentation = [ "man:kea-dhcp4(8)" "https://kea.readthedocs.io/en/kea-${package.version}/arm/dhcp4-srv.html" ];
          after = [ "network-online.target" "time-sync.target" ];
          wantedBy = [ "multi-user.target" ];
          environment = { KEA_PIDFILE_DIR = "/run/kea"; KEA_LOCKFILE_DIR = "/run/kea"; };
          restartTriggers = [ configs.${interface} ];

          serviceConfig = {
            ExecStart = "${package}/bin/kea-dhcp4 -c "
              + lib.escapeShellArgs ([ "/etc/kea/dhcp4-server-${interface}.conf" ]);
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
          } // commonServiceConfig;
        });
      });
    })
    (let
      configs = lib.flip builtins.mapAttrs cfg.interfaces (interface: icfg:
      let
        cfg6 = icfg.ipv6.kea;
      in if cfg6.configFile != null then cfg6.configFile else (format.generate "kea-dhcp6-${interface}.conf" {
        Dhcp6 = {
          valid-lifetime = 4000;
          preferred-lifetime = 3000;
          interfaces-config.interfaces = [ interface ];
          lease-database = {
            type = "memfile";
            persist = true;
            name = "/var/lib/private/kea/dhcp6-${interface}.leases";
          };
          subnet6 = map ({ address, prefixLength, dns, keaSettings, ... }:
          let
            subnetMask = router-lib.genMask6 prefixLength;
            parsed = router-lib.parseIp6 address;
            minIp = router-lib.andMask subnetMask parsed;
            maxIp = router-lib.orMask (router-lib.invMask6 subnetMask) parsed;
          in {
            inherit interface;
            option-data =
              lib.optional (dns != [ ]) {
                name = "dns-servers";
                code = 23;
                csv-format = true;
                space = "dhcp6";
                data = builtins.concatStringsSep ", " (map (x: if builtins.isString x then x else x.address) dns);
              };
            subnet = router-lib.serializeCidr { inherit address prefixLength; };
            pools = let
              a = addToLastComp6 16 minIp;
              b = addToLastComp6 (-16) parsed;
              c = addToLastComp6 16 parsed;
              d = addToLastComp6 (-16) maxIp;
            in
              lib.optional (a != null && b != null && a <= b) {
                pool = "${router-lib.serializeIp6 a}-${router-lib.serializeIp6 b}";
              } ++ lib.optional (c != null && d != null && c <= d) {
                pool = "${router-lib.serializeIp6 c}-${router-lib.serializeIp6 d}";
              };
          } // keaSettings) icfg.ipv6.addresses;
        } // cfg6.settings;
      }));
    in {
      environment.etc = lib.mapAttrs' (interface: icfg: {
        name = "kea/dhcp6-server-${utils.escapeSystemdPath interface}.conf";
        value = lib.mkIf (icfg.ipv6.kea.enable && icfg.ipv6.addresses != [ ]) {
          source = configs.${interface};
        };
      }) cfg.interfaces;

      systemd.services = lib.flip lib.mapAttrs' cfg.interfaces (interface: icfg: {
        name = "kea-dhcp6-server-${utils.escapeSystemdPath interface}";
        value = lib.mkIf (icfg.ipv6.kea.enable && icfg.ipv6.addresses != [ ]) (router-lib.mkServiceForIf interface {
          description = "Kea DHCP6 Server (${interface})";
          documentation = [ "man:kea-dhcp6(8)" "https://kea.readthedocs.io/en/kea-${package.version}/arm/dhcp6-srv.html" ];
          after = [ "network-online.target" "time-sync.target" ];
          wantedBy = [ "multi-user.target" ];
          environment = { KEA_PIDFILE_DIR = "/run/kea"; KEA_LOCKFILE_DIR = "/run/kea"; };
          restartTriggers = [ configs.${interface} ];

          serviceConfig = {
            ExecStart = "${package}/bin/kea-dhcp6 -c "
              + lib.escapeShellArgs ([ "/etc/kea/dhcp6-server-${interface}.conf" ]);
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
          } // commonServiceConfig;
        });
      });
    })
  ]);
}
