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
in
{
  config = lib.mkIf cfg.enable {
    systemd.services = lib.flip lib.mapAttrs' cfg.interfaces (
      interface: icfg:
      let
        cfg = icfg.ipv6.corerad;
        settingsFormat = pkgs.formats.toml { };
        ifaceConfig = {
          name = interface;
          monitor = false;
          advertise = true;
          managed = icfg.ipv6.kea.enable && icfg.ipv6.addresses != [ ];
          other_config = icfg.ipv6.kea.enable && icfg.ipv6.addresses != [ ];
        } // cfg.interfaceSettings;
        configFile =
          if cfg.configFile != null then
            cfg.configFile
          else
            settingsFormat.generate "corerad-${interface}.toml" (
              {
                interfaces = [
                  (
                    ifaceConfig
                    // {
                      prefix = map (
                        {
                          address,
                          prefixLength,
                          coreradSettings,
                          ...
                        }:
                        {
                          prefix = router-lib.serializeCidr (router-lib.applyMask { inherit address prefixLength; });
                          autonomous = !ifaceConfig.managed;
                        }
                        // coreradSettings
                      ) icfg.ipv6.addresses;
                      route = builtins.concatLists (
                        map (
                          {
                            address,
                            prefixLength,
                            gateways,
                            ...
                          }:
                          map (
                            gateway:
                            {
                              prefix = router-lib.serializeCidr (
                                router-lib.applyMask {
                                  address = if builtins.isString gateway then gateway else gateway.address;
                                  prefixLength = if gateway.prefixLength or null != null then gateway.prefixLength else prefixLength;
                                }
                              );
                            }
                            // (gateway.coreradSettings or { })
                          ) gateways
                        ) icfg.ipv6.addresses
                      );
                      rdnss = builtins.concatLists (
                        map (
                          { dns, ... }:
                          map (
                            dns:
                            {
                              servers = if builtins.isString dns then [ dns ] else [ dns.address ];
                            }
                            // (dns.coreradSettings or { })
                          ) dns
                        ) icfg.ipv6.addresses
                      );
                    }
                    // cfg.interfaceSettings
                  )
                ];
              }
              // cfg.settings
            );
        package = pkgs.corerad;
      in
      {
        name = "corerad-${utils.escapeSystemdPath interface}";
        value = lib.mkIf icfg.ipv6.corerad.enable (
          router-lib.mkServiceForIf interface {
            description = "CoreRAD IPv6 NDP RA daemon (${interface})";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              LimitNPROC = 512;
              LimitNOFILE = 1048576;
              CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_RAW";
              AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_RAW";
              NoNewPrivileges = true;
              DynamicUser = true;
              Type = "notify";
              NotifyAccess = "main";
              ExecStart = "${lib.getBin package}/bin/corerad -c=${configFile}";
              Restart = "on-failure";
              RestartKillSignal = "SIGHUP";
            };
          }
        );
      }
    );
  };
}
