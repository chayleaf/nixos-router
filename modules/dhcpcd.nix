{
  lib,
  config,
  pkgs,
  utils,
  router-lib,
  ...
}:

let
  cfg = config.router;
  exitHook = pkgs.writeText "dhcpcd.exit-hook" ''
    if [ "$reason" = BOUND -o "$reason" = REBOOT ]; then
        # Restart ntpd.  We need to restart it to make sure that it
        # will actually do something: if ntpd cannot resolve the
        # server hostnames in its config file, then it will never do
        # anything ever again ("couldn't resolve ..., giving up on
        # it"), so we silently lose time synchronisation. This also
        # applies to openntpd.
        /run/current-system/systemd/bin/systemctl try-reload-or-restart ntpd.service openntpd.service chronyd.service || true
    fi
  '';
in
{
  config =
    lib.mkIf (cfg.enable && builtins.any (x: x.dhcpcd.enable) (builtins.attrValues cfg.interfaces))
      {
        users.users.dhcpcd = {
          isSystemUser = true;
          group = "dhcpcd";
        };
        users.groups.dhcpcd = { };
        environment.systemPackages = [ pkgs.dhcpcd ];
        environment.etc."dhcpcd.exit-hook".source = exitHook;

        powerManagement.resumeCommands = builtins.concatStringsSep "\n" (
          lib.mapAttrsToList (interface: icfg: ''
            # Tell dhcpcd to rebind its interfaces if it's running.
            /run/current-system/systemd/bin/systemctl reload "dhcpcd-${utils.escapeSystemdPath interface}.service"
          '') cfg.interfaces
        );

        systemd.services = lib.flip lib.mapAttrs' cfg.interfaces (
          interface: icfg:
          let
            dhcpcdConf = pkgs.writeText "dhcpcd-${interface}.conf" ''
              hostname
              option domain_name_servers, domain_name, domain_search, host_name
              option classless_static_routes, ntp_servers, interface_mtu
              nohook lookup-hostname
              denyinterfaces ve-* vb-* lo peth* vif* tap* tun* virbr* vnet* vboxnet* sit*
              allowinterfaces ${interface}
              waitip
              ${icfg.dhcpcd.extraConfig}
            '';
          in
          {
            name = "dhcpcd-${utils.escapeSystemdPath interface}";
            value = lib.mkIf icfg.dhcpcd.enable (
              router-lib.mkServiceForIf interface {
                description = "DHCP Client for ${interface}";
                wantedBy = [
                  "multi-user.target"
                  "network-online.target"
                ];
                wants = [ "network.target" ];
                before = [ "network-online.target" ];
                restartTriggers = [ exitHook ];
                stopIfChanged = false;
                path = [
                  pkgs.dhcpcd
                  pkgs.nettools
                  config.networking.resolvconf.package
                ];
                unitConfig.ConditionCapability = "CAP_NET_ADMIN";
                serviceConfig = {
                  Type = "forking";
                  PIDFile = "/run/dhcpcd/${interface}.pid";
                  RuntimeDirectory = "dhcpcd";
                  ExecStart = "@${pkgs.dhcpcd}/sbin/dhcpcd dhcpcd --quiet --config ${dhcpcdConf} ${lib.escapeShellArg interface}";
                  ExecReload = "${pkgs.dhcpcd}/sbin/dhcpcd --rebind";
                  Restart = "always";
                };
              }
            );
          }
        );
      };
}
