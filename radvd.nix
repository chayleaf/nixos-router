{ lib
, config
, pkgs
, utils
, router-lib
, ... }:

let
  cfg = config.router;
in {
  config = lib.mkIf (cfg.enable && builtins.any (x: x.ipv6.radvd.enable) (builtins.attrValues cfg.interfaces)) {
    users.users.radvd = {
      isSystemUser = true;
      group = "radvd";
      description = "Router Advertisement Daemon User";
    };
    users.groups.radvd = { };

    systemd.services = lib.mapAttrs' (interface: icfg: let
      ifaceOpts = {
        AdvSendAdvert = true;
        AdvManagedFlag = icfg.ipv6.kea.enable && icfg.ipv6.addresses != [ ];
        AdvOtherConfigFlag = icfg.ipv6.kea.enable && icfg.ipv6.addresses != [ ];
      } // icfg.ipv6.radvd.interfaceSettings;
      prefixOpts = {
        # if dhcp6 is enabled: don't autoconfigure addresses, ask dhcp
        AdvAutonomous = !ifaceOpts.AdvManagedFlag;
      };
      compileOpt = x:
        if x == true then "on"
        else if x == false then "off"
        else toString x;
      compileOpts = lib.mapAttrsToList (k: v: "${k} ${compileOpt v};");
      indent = map (x: "  " + x);
      confFile = pkgs.writeText "radvd-${interface}.conf" (
        builtins.concatStringsSep "\n" (
        [ "interface ${interface} {" ]
        ++ indent (
          compileOpts ifaceOpts
          ++ builtins.concatLists (map ({ address, gateways, prefixLength, dns, radvdSettings, ... }:
            [ "prefix ${address}/${toString prefixLength} {" ]
            ++ indent (compileOpts (prefixOpts // radvdSettings))
            ++ [ "};" ]
            ++ (builtins.concatLists (map (gateway:
              [ "route ${if builtins.isString gateway then gateway else gateway.address}/${toString (if gateway.prefixLength or null != null then gateway.prefixLength else prefixLength)} {" ]
              ++ indent (compileOpts (gateway.radvdSettings or { }))
              ++ [ "};" ]) gateways))
            ++ (builtins.concatLists (map (dns:
              [ "RDNSS ${if builtins.isString dns then dns else dns.address} {" ]
              ++ indent (compileOpts (dns.radvdSettings or { }))
              ++ [ "};" ]) dns))) icfg.ipv6.addresses)
        ) ++ [ "};" ]));
      package = pkgs.radvd;
    in {
      name = "radvd-${utils.escapeSystemdPath interface}";
      value = lib.mkIf icfg.ipv6.radvd.enable (router-lib.mkServiceForIf interface {
        description = "IPv6 Router Advertisement Daemon (${interface})";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "@${package}/bin/radvd radvd -n -u radvd -C ${confFile}";
          Restart = "always";
        };
      });
    }) cfg.interfaces;
  };
}
