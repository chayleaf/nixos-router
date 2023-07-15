{ lib
, config
, pkgs
, utils
, ... }:

let
  notnft = config._module.args.notnft or config.notnft or null;
  cfg = config.router;
  nftFlags = "";
  mkNftStartCmd = attrs: let
    haveTextFile = attrs.nftables.textFile != null;
    haveTextRules = attrs.nftables.textRules != null;
    haveStopTextFile = attrs.nftables.stopTextFile != null;
    haveStopTextRules = attrs.nftables.stopTextRules != null;
    haveJsonFile = attrs.nftables.jsonFile != null;
    haveJsonRules = attrs.nftables.jsonRules != null;
    haveStopJsonFile = attrs.nftables.stopJsonFile != null;
    haveStopJsonRules = attrs.nftables.stopJsonRules != null;
    jsonAfter = haveStopTextRules;
    injectStopRules =
      # if stop files are used, call stop explicitly
      !haveStopTextFile && !haveStopJsonFile
      # if text/json stop rules exist, ensure associated text/json start rules exist 
      && (haveStopTextRules -> haveTextRules) && (haveStopJsonRules -> haveJsonRules)
      # if text rules AND json rules are set, call stop explicitly
      && (haveStopTextRules -> !haveStopJsonRules);
    stopRulesEmpty = !haveStopJsonRules && !haveStopTextRules && !haveStopTextFile && !haveStopJsonFile;
    nft = "${pkgs.nftables}/bin/nft";
  in ''
    ${lib.optionalString stopRulesEmpty "${nft} ${nftFlags} flush ruleset"}
    ${lib.optionalString (!stopRulesEmpty && !injectStopRules) (mkNftStopCmd attrs)}
    ${lib.optionalString (!jsonAfter && haveJsonRules) "${nft} -j ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.json";
      text = builtins.toJSON {
        nftables = (if injectStopRules && haveStopJsonRules
                    then attrs.nftables.stopJsonRules.nftables
                    else [])
                   ++ attrs.nftables.jsonRules.nftables;
      };
    }}"}
    ${lib.optionalString haveTextRules "${nft} ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.nft";
      text = (if injectStopRules && haveStopTextRules
              then attrs.nftables.stopTextRules + "\n"
              else "") + attrs.nftables.textRules;
    }}"}
    ${lib.optionalString haveTextFile "${nft} ${nftFlags} -f ${attrs.nftables.textFile}"}
    ${lib.optionalString haveJsonFile "${nft} -j ${nftFlags} -f ${attrs.nftables.jsonFile}"}
    ${lib.optionalString (jsonAfter && haveJsonRules) "${nft} -j ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.json";
      text = builtins.toJSON {
        nftables = (if injectStopRules && haveStopJsonRules then attrs.nftables.stopJsonRules.nftables else []) ++ attrs.nftables.jsonRules.nftables;
      };
    }}"}
  '';
  mkNftStopCmd = attrs: ''
    ${lib.optionalString (attrs.nftables.stopTextFile != null) "${pkgs.nftables}/bin/nft ${nftFlags} -f ${attrs.nftables.stopTextFile}"}
    ${lib.optionalString (attrs.nftables.stopTextRules != null) "${pkgs.nftables}/bin/nft ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.nft";
      text = attrs.nftables.stopTextRules;
    }}"}
    ${lib.optionalString (attrs.nftables.stopJsonFile != null) "${pkgs.nftables}/bin/nft -j ${nftFlags} -f ${attrs.nftables.stopJsonFile}"}
    ${lib.optionalString (attrs.nftables.stopJsonRules != null) "${pkgs.nftables}/bin/nft -j ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.json";
      text = builtins.toJSON attrs.nftables.stopJsonRules;
    }}"}
  '';
  hasNftablesRules = x:
    x.nftables.textFile != null
    || x.nftables.textRules != null
    || x.nftables.jsonFile != null
    || x.nftables.jsonRules != null
    || x.nftables.stopTextFile != null
    || x.nftables.stopTextRules != null
    || x.nftables.stopJsonFile != null
    || x.nftables.stopJsonRules != null;
  nftType = extraDesc: extraStopDesc: lib.types.submodule {
    options.textFile = lib.mkOption {
      description = "Text rules file to run${extraDesc}.";
      type = with lib.types; nullOr path;
      default = null;
    };
    options.textRules = lib.mkOption {
      description = "Text rules to run${extraDesc}. Make sure to add \"flush ruleset\" as the first line if you want to reset old rules!";
      type = with lib.types; nullOr lines;
      default = null;
    };
    options.jsonFile = lib.mkOption {
      description = "JSON rules file to run${extraDesc}.";
      type = with lib.types; nullOr path;
      default = null;
    };
    options.jsonRules = lib.mkOption {
      description = "JSON rules to run${extraDesc}.";
      type = lib.types.nullOr (notnft.types.ruleset or (pkgs.formats.json {}).type);
      default = null;
    };
    options.stopTextFile = lib.mkOption {
      description = "Text rules file to run${extraStopDesc}. Make sure to set this to \"flush ruleset\" if you want to reset the old rules!";
      type = with lib.types; nullOr path;
      default = null;
    };
    options.stopTextRules = lib.mkOption {
      description = "Text rules to run${extraStopDesc}. Make sure to add \"flush ruleset\" as the first line if you want to reset old rules!";
      type = with lib.types; nullOr lines;
      default = null;
    };
    options.stopJsonFile = lib.mkOption {
      description = "JSON rules file to run${extraStopDesc}.";
      type = with lib.types; nullOr path;
      default = null;
    };
    options.stopJsonRules = lib.mkOption {
      description = "JSON rules to run${extraStopDesc}.";
      type = lib.types.nullOr (notnft.types.ruleset or (pkgs.formats.json {}).type);
      default = null;
    };
  };
  # a set of { <bridgeName> = [ <bridge interfaces> ]; }
  bridges = lib.zipAttrs
    (lib.mapAttrsToList
      (interface: icfg: if icfg.bridge == null || icfg.hostapd.enable then { } else {
        ${icfg.bridge} = interface;
      }) cfg.interfaces);
  systemHasNftables = config.networking.nftables.enable
    || builtins.any hasNftablesRules (builtins.attrValues cfg.networkNamespaces);
  router-lib = import ./lib.nix {
    inherit lib config utils;
  };
in {
  imports = [
    ./modules/hostapd.nix
    ./modules/kea.nix
    ./modules/radvd.nix
    ./modules/corerad.nix
    ./modules/dhcpcd.nix
  ];

  options.router = {
    enable = lib.mkEnableOption "router config";
    networkNamespaces = lib.mkOption {
      description = "Network namespace config (default = default namespace)";
      type = lib.types.attrsOf (lib.types.submodule {
        options.nftables = lib.mkOption {
          description = "Per-namespace nftables rules.";
          default = { };
          type = nftType " on namespace start" " on namespace stop *and before the first start*";
        };
        options.extraStartCommands = lib.mkOption {
          description = "Start commands for this namespace.";
          default = "";
          type = lib.types.lines;
        };
        options.extraStopCommands = lib.mkOption {
          description = "Stop commands for this namespace.";
          default = "";
          type = lib.types.lines;
        };
        options.rules = lib.mkOption {
          description = "IP routing rules added when this network namespace starts";
          default = [ ];
          type = lib.types.listOf (lib.types.submodule {
            options.ipv6 = lib.mkOption {
              description = "Whether this rule is ipv6";
              type = lib.types.bool;
            };
            options.extraArgs = lib.mkOption {
              description = "Rule args, i.e. everything after \"ip rule add\"";
              type = with lib.types; either str (listOf anything);
            };
          });
        };
      });
    };
    veths = lib.mkOption {
      default = { };
      description = "veth pairs";
      type = lib.types.attrsOf (lib.types.submodule {
        options.peerName = lib.mkOption {
          description = "Name of veth peer (the second veth device created at the same time)";
        };
      });
    };
    interfaces = lib.mkOption {
      default = { };
      description = "All interfaces managed by nixos-router";
      type = lib.types.attrsOf (lib.types.submodule {
        options.dependentServices = lib.mkOption {
          description = "Patch those systemd services to depend on this interface";
          default = [ ];
          type = with lib.types; listOf (either str attrs);
        };
        options.bridge = lib.mkOption {
          description = "Add this device to this bridge";
          default = null;
          type = with lib.types; nullOr str;
        };
        options.networkNamespace = lib.mkOption {
          description = "Network namespace name to create this device in";
          default = null;
          type = with lib.types; nullOr str;
        };
        options.systemdLinkLinkConfig = lib.mkOption {
          description = "This device's systemd.link(5) link config";
          default = { };
          type = lib.types.attrs;
        };
        options.systemdLinkMatchConfig = lib.mkOption {
          description = "This device's systemd.link(5) match config";
          default = { };
          type = lib.types.attrs;
        };
        options.hostapd = lib.mkOption {
          description = "hostapd options";
          default = { };
          type = lib.types.submodule {
            options.enable = lib.mkEnableOption "hostapd";
            options.settings = lib.mkOption {
              description = "hostapd config";
              default = { };
              type = lib.types.attrs;
            };
          };
        };
        options.dhcpcd = lib.mkOption {
          description = "dhcpcd options";
          default = { };
          type = lib.types.submodule {
            options.enable = lib.mkEnableOption "dhcpcd (this option disables networking.useDHCP)";
            options.extraConfig = lib.mkOption {
              description = "dhcpcd text config";
              default = "";
              type = lib.types.lines;
            };
          };
        };
        options.ipv4 = lib.mkOption {
          description = "IPv4 config";
          default = { };
          type = lib.types.submodule {
            options.enableForwarding = lib.mkEnableOption "Enable IPv4 forwarding for this device";
            options.rpFilter = lib.mkOption {
              description = "rp_filter value for this device (see kernel docs for more info)";
              type = with lib.types; nullOr int;
              default = null;
            };
            options.addresses = lib.mkOption {
              description = "Device's IPv4 addresses";
              default = [ ];
              type = lib.types.listOf (lib.types.submodule {
                options.address = lib.mkOption {
                  description = "IPv4 address";
                  type = router-lib.types.ipv4;
                };
                options.prefixLength = lib.mkOption {
                  description = "IPv4 prefix length";
                  type = lib.types.int;
                };
                options.assign = lib.mkOption {
                  description = "Whether to assign this address to the device. Default: no if the first hextet is zero, yes otherwise.";
                  type = with lib.types; nullOr bool;
                  default = null;
                };
                options.gateways = lib.mkOption {
                  description = "IPv4 gateway addresses (optional)";
                  default = null;
                  type = with lib.types; nullOr (listOf str);
                };
                options.dns = lib.mkOption {
                  description = "IPv4 DNS servers associated with this device";
                  type = with lib.types; listOf str;
                  default = [ ];
                };
                options.keaSettings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.json {}).type;
                  example = lib.literalExpression {
                    pools = [ { pool = "192.168.1.15 - 192.168.1.200"; } ];
                    option-data = [ {
                      name = "domain-name-servers";
                      code = 6;
                      csv-format = true;
                      space = "dhcp4";
                      data = "8.8.8.8, 8.8.4.4";
                    } ];
                  };
                  description = "Kea IPv4 prefix-specific settings";
                };
              });
            };
            options.routes = lib.mkOption {
              description = "IPv4 routes added when this device starts";
              default = [ ];
              type = lib.types.listOf (lib.types.submodule {
                options.extraArgs = lib.mkOption {
                  description = "Route args, i.e. everything after \"ip route add\"";
                  type = with lib.types; either str (listOf anything);
                };
              });
            };
            options.kea = lib.mkOption {
              description = "Kea options";
              default = { };
              type = lib.types.submodule {
                options.enable = lib.mkEnableOption "Kea for IPv4";
                options.extraArgs = lib.mkOption {
                  type = with lib.types; listOf str;
                  default = [ ];
                  description = "List of additional arguments to pass to the daemon.";
                };
                options.configFile = lib.mkOption {
                  type = with lib.types; nullOr path;
                  default = null;
                  description = "Kea config file (takes precedence over settings)";
                };
                options.settings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.json {}).type;
                  description = "Kea settings";
                };
              };
            };
          };
        };
        options.ipv6 = lib.mkOption {
          description = "IPv6 config";
          default = { };
          type = lib.types.submodule {
            options.enableForwarding = lib.mkEnableOption "Enable IPv6 forwarding for this device";
            options.addresses = lib.mkOption {
              description = "Device's IPv6 addresses";
              default = [ ];
              type = lib.types.listOf (lib.types.submodule {
                options.address = lib.mkOption {
                  description = "IPv6 address";
                  type = router-lib.types.ipv6;
                };
                options.prefixLength = lib.mkOption {
                  description = "IPv6 prefix length";
                  type = lib.types.int;
                };
                options.assign = lib.mkOption {
                  description = "Whether to assign this address to the device. Default: no if the first hextet is zero, yes otherwise";
                  type = with lib.types; nullOr bool;
                  default = null;
                };
                options.gateways = lib.mkOption {
                  description = "IPv6 gateways information (optional)";
                  default = [ ];
                  type = with lib.types; listOf (either router-lib.types.ipv6 (submodule {
                    options.address = lib.mkOption {
                      description = "Gateway's IPv6 address";
                      type = router-lib.types.ipv6;
                    };
                    options.prefixLength = lib.mkOption {
                      description = "Gateway's IPv6 prefix length (defaults to interface address's prefix length)";
                      type = nullOr int;
                      default = null;
                    };
                    options.radvdSettings = lib.mkOption {
                      default = { };
                      type = attrsOf (oneOf [ bool str int ]);
                      example = lib.literalExpression {
                        AdvRoutePreference = "high";
                      };
                      description = "radvd prefix-specific route settings";
                    };
                    options.coreradSettings = lib.mkOption {
                      default = { };
                      type = (pkgs.formats.toml {}).type;
                      example = lib.literalExpression {
                        preference = "high";
                      };
                      description = "CoreRAD prefix-specific route settings";
                    };
                  }));
                };
                options.dns = lib.mkOption {
                  description = "IPv6 DNS servers associated with this device";
                  type = with lib.types; listOf (either str (submodule {
                    options.address = lib.mkOption {
                      description = "DNS server's address";
                      type = lib.types.str;
                    };
                    options.radvdSettings = lib.mkOption {
                      default = { };
                      type = attrsOf (oneOf [ bool str int ]);
                      example = lib.literalExpression { FlushRDNSS = false; };
                      description = "radvd prefix-specific RDNSS settings";
                    };
                    options.coreradSettings = lib.mkOption {
                      default = { };
                      type = (pkgs.formats.toml {}).type;
                      example = lib.literalExpression { lifetime = "auto"; };
                      description = "CoreRAD prefix-specific RDNSS settings";
                    };
                  }));
                  default = [ ];
                };
                options.keaSettings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.json {}).type;
                  example = lib.literalExpression {
                    pools = [ {
                      pool = "fd01:: - fd01::ffff:ffff:ffff:ffff";
                    } ];
                    option-data = [ {
                      name = "dns-servers";
                      code = 23;
                      csv-format = true;
                      space = "dhcp6";
                      data = "aaaa::, bbbb::";
                    } ];
                  };
                  description = "Kea prefix-specific settings";
                };
                options.radvdSettings = lib.mkOption {
                  default = { };
                  type = with lib.types; attrsOf (oneOf [ bool str int ]);
                  example = lib.literalExpression {
                    AdvOnLink = true;
                    AdvAutonomous = true;
                    Base6to4Interface = "ppp0";
                  };
                  description = "radvd prefix-specific settings";
                };
                options.coreradSettings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.toml {}).type;
                  example = lib.literalExpression {
                    on_link = true;
                    autonomous = true;
                  };
                  description = "CoreRAD prefix-specific settings";
                };
              });
            };
            options.routes = lib.mkOption {
              description = "IPv6 routes added when this device starts";
              default = [ ];
              type = lib.types.listOf (lib.types.submodule {
                options.extraArgs = lib.mkOption {
                  description = "Route args, i.e. everything after \"ip route add\"";
                  type = with lib.types; either str (listOf anything);
                };
              });
            };
            options.kea = lib.mkOption {
              description = "Kea options";
              default = { };
              type = lib.types.submodule {
                options.enable = lib.mkEnableOption "Kea for IPv6";
                options.extraArgs = lib.mkOption {
                  type = with lib.types; listOf str;
                  default = [ ];
                  description = "List of additional arguments to pass to the daemon.";
                };
                options.configFile = lib.mkOption {
                  type = with lib.types; nullOr path;
                  default = null;
                  description = "Kea config file (takes precedence over settings)";
                };
                options.settings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.json {}).type;
                  description = "Kea settings";
                };
              };
            };
            options.radvd = lib.mkOption {
              description = "radvd options";
              default = { };
              type = lib.types.submodule {
                options.enable = lib.mkEnableOption "radvd";
                options.interfaceSettings = lib.mkOption {
                  default = { };
                  type = with lib.types; attrsOf (oneOf [ bool str int ]);
                  example = lib.literalExpression {
                    UnicastOnly = true;
                  };
                  description = "radvd interface-specific settings";
                };
              };
            };
            options.corerad = lib.mkOption {
              description = "CoreRAD options";
              default = { };
              type = lib.types.submodule {
                options.enable = lib.mkEnableOption "CoreRAD";
                options.configFile = lib.mkOption {
                  type = with lib.types; nullOr path;
                  default = null;
                  description = "CoreRAD config file (takes precedence over settings)";
                };
                options.interfaceSettings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.toml {}).type;
                  description = "CoreRAD interface-specific settings";
                };
                options.settings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.toml {}).type;
                  example = lib.literalExpression {
                    debug.address = "localhost:9430";
                    debug.prometheus = true;
                  };
                  description = "General CoreRAD settings";
                };
              };
            };
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [ {
    _module.args = {
      inherit router-lib;
    };

    environment.systemPackages = with pkgs; [
      bind
      conntrack-tools
      dig.dnsutils
      ethtool
      nftables
      tcpdump
    ];

    boot.blacklistedKernelModules = lib.optional systemHasNftables "ip_tables";

    # performance tweaks
    powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
    services.irqbalance.enable = lib.mkDefault true;
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_xanmod;

    boot.kernel.sysctl = {
      "net.netfilter.nf_log_all_netns" = true;
    } // builtins.zipAttrsWith (k: builtins.head) (lib.flip lib.mapAttrsToList cfg.interfaces (name: icfg:
      lib.optionalAttrs (icfg.ipv4.rpFilter != null) {
        "net.ipv4.conf.${name}.rp_filter" = icfg.ipv4.rpFilter;
      } // lib.optionalAttrs icfg.ipv4.enableForwarding {
        "net.ipv4.conf.${name}.forwarding" = true;
      } // lib.optionalAttrs icfg.ipv6.enableForwarding {
        "net.ipv6.conf.${name}.forwarding" = true;
      }));

    networking.usePredictableInterfaceNames = true;
    networking.firewall.filterForward = lib.mkDefault false;
    networking.firewall.allowPing = lib.mkDefault true;
    networking.firewall.rejectPackets = lib.mkDefault false; # drop rather than reject
    # networking.firewall.package = lib.mkIf systemHasNftables (lib.mkDefault pkgs.nftables);
    # ^ it uses networking.nftables, so i don't touch it
    networking.networkmanager.firewallBackend = lib.mkIf systemHasNftables (lib.mkDefault "nftables");
    services.fail2ban.banaction = lib.mkIf systemHasNftables (lib.mkDefault "nftables-multiport");
    services.fail2ban.banaction-allports = lib.mkIf systemHasNftables (lib.mkDefault "nftables-allport");
    services.fail2ban.packageFirewall = lib.mkIf systemHasNftables (lib.mkDefault pkgs.nftables);
    services.opensnitch.settings.Firewall = lib.mkIf systemHasNftables (lib.mkDefault "nftables");

    router.networkNamespaces =
      builtins.zipAttrsWith (k: vs: { })
        (builtins.filter (x: x != null)
          ([ { default = null; } ] ++ lib.mapAttrsToList
            (k: v: if v.networkNamespace == null then null else { ${v.networkNamespace} = null; })
            cfg.interfaces));

    systemd.services = lib.flip lib.mapAttrs' cfg.interfaces (interface: icfg: let
      escapedInterface = utils.escapeSystemdPath interface;
      ips = (builtins.filter
              (x: x.assign == true || (x.assign == null && !(lib.hasPrefix "0." x.address)))
              icfg.ipv4.addresses)
         ++ (builtins.filter
              (x: x.assign == true || (x.assign == null && !(lib.hasPrefix ":" x.address || lib.hasPrefix "0:" x.address)))
              icfg.ipv6.addresses);
      routeFlags = x: if builtins.isList x.extraArgs then lib.escapeShellArgs (map toString x.extraArgs) else x.extraArgs;
      routes4 = map routeFlags icfg.ipv4.routes;
      routes6 = map routeFlags icfg.ipv6.routes;
    in {
      # network-addresses config
      # sets up per-device addresses and routes
      # nixos does it too, but the way it does it is too simple and doesn't work for some routers
      name = "network-addresses-${escapedInterface}";
      value = assert lib.assertMsg
        (!config.networking.interfaces?${interface})
        "router.interfaces and networking.interfaces are incompatible! Remove interface `${interface}` from at least one of them.";
      router-lib.mkServiceForIf interface {
        description = "Address configuration of ${interface}";
        wantedBy = [ "network-setup.service" "network.target" ];
        before = [ "network-setup.service" ];
        after = [ "network-pre.target" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        stopIfChanged = false;
        path = [ pkgs.iproute2 ];
        script = ''
          state="/run/nixos/network/addresses/${interface}"
          mkdir -p $(dirname "$state")
          ${lib.optionalString (icfg.bridge != null && !icfg.hostapd.enable) ''
            ip link set "${interface}" master "${icfg.bridge}" up && echo "${interface} " >> "/run/${icfg.bridge}.interfaces" || true
          ''}
          ip link set "${interface}" up
          ${lib.flip lib.concatMapStrings ips (ip:
            let cidr = "${ip.address}/${toString ip.prefixLength}"; in ''
              echo "${cidr}" >> $state
              echo -n "adding address ${cidr}... "
              if out=$(ip addr add "${cidr}" dev "${interface}" 2>&1); then
                echo "done"
              elif ! echo "$out" | grep "File exists" >/dev/null 2>&1; then
                echo "'ip addr add "${cidr}" dev "${interface}"' failed: $out"
                exit 1
              fi
            ''
          )}
          state="/run/nixos/network/routes/${interface}"
          mkdir -p $(dirname "$state")
          echo -n "" > "$state"
          ${lib.concatMapStrings (route: ''
            echo -n "adding route ${route}... "
            if out=$(ip -4 route add ${route} 2>&1 && echo ${lib.escapeShellArg ("ip -4 route del " + route)} >> "$state"); then
              echo "done"
            elif ! echo "$out" | grep "File exists" >/dev/null 2>&1; then
              echo "'ip -4 route add "${lib.escapeShellArg route}"' failed: $out"
              exit 1
            fi
          '') routes4}
          ${lib.concatMapStrings (route: ''
            echo -n "adding route ${route}... "
            if out=$(ip -6 route add ${route} 2>&1 && echo ${lib.escapeShellArg ("ip -6 route del " + route)} >> "$state"); then
              echo "done"
            elif ! echo "$out" | grep "File exists" >/dev/null 2>&1; then
              echo "'ip -6 route add "${lib.escapeShellArg route}"' failed: $out"
              exit 1
            fi
          '') routes6}
        '';
        preStop = ''
          state="/run/nixos/network/routes/${interface}"
          ${lib.optionalString (icfg.bridge != null && !icfg.hostapd.enable) ''
            ip link set "${interface}" nomaster up && echo "${interface} " >> "/run/${icfg.bridge}.interfaces" || true
          ''}
          if [ -e "$state" ]; then
            while read cmd; do
              echo -n "running route delete command $cmd... "
              $cmd >/dev/null 2>&1 && echo "done" || echo "failed"
            done < "$state"
            rm -f "$state"
          fi

          state="/run/nixos/network/addresses/${interface}"
          if [ -e "$state" ]; then
            while read cidr; do
              echo -n "deleting address $cidr... "
              ip addr del "$cidr" dev "${interface}" >/dev/null 2>&1 && echo "done" || echo "failed"
            done < "$state"
            rm -f "$state"
          fi
        '';
      };
    })
    // lib.flip lib.mapAttrs' bridges (interface: value: let
      escapedInterface = utils.escapeSystemdPath interface;
    in {
      name = "${escapedInterface}-netdev";
      value = router-lib.mkServiceForIf' { inherit interface; includeBasicDeps = false; } {
        description = "Router Bridge Interface ${interface}";
        wantedBy = [ "network-setup.service" "sys-subsystem-net-devices-${escapedInterface}.device" ];
        partOf = [ "network-setup.service" ];
        after = [ "network-pre.target" ]
          # soft dependency, order it but don't require
          ++ map router-lib.mainDepForIf value;
        before = [ "network-setup.service" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        path = [ pkgs.iproute2 ];
        script = ''
          ip link show dev "${interface}" >/dev/null 2>&1 && ip link del "${interface}" || true
          echo "Adding bridge ${interface}..."
          ip link add name "${interface}" type bridge
          ip link set "${interface}" up
          echo -n > "/run/${interface}.interfaces"
          ${lib.concatMapStrings (i: ''
            ip link set "${i}" master "${interface}" up && echo "${i} " >> "/run/${interface}.interfaces" || true
          '') value}
          ip link set "${interface}" up
        '';
        postStop = ''
          ip link set "${interface}" down || true
          ip link del "${interface}" || true
          rm -f "/run/${interface}.interfaces"
        '';
        reload = ''
          for interface in `cat /run/${interface}.interfaces`; do
            ip link set "$interface" nomaster up || true
          done
          ${lib.concatMapStrings (i: ''
            ip link set "${i}" master "${interface}" up && echo "${i}" >> "/run/${interface}.interfaces" || true
          '') value}
        '';
        reloadIfChanged = true;
      };
    })
    // lib.flip lib.mapAttrs' cfg.veths (interface: value: let
      escapedInterface = utils.escapeSystemdPath interface;
      escapedPeerInterface = utils.escapeSystemdPath value.peerName;
    in {
      name = "${escapedInterface}-netdev";
      value = router-lib.mkServiceForIf' { inherit interface; includeBasicDeps = false; } {
        description = "Virtual Ethernet Interfaces ${interface}/${value.peerName}";
        wantedBy = [
          "network-setup.service"
          "sys-subsystem-net-devices-${escapedInterface}.device"
          "sys-subsystem-net-devices-${escapedPeerInterface}.device"
        ];
        partOf = [ "network-setup.service" ];
        after = [ "network-pre.target" ];
        before = [ "network-setup.service" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        stopIfChanged = false;
        path = [ pkgs.iproute2 ];
        script = ''
          ip link show dev "${interface}" >/dev/null 2>&1 && ip link del "${interface}" || true
          echo "Adding veth ${interface}..."
          ip link add name "${interface}" type veth peer name "${value.peerName}"
          ip link set "${interface}" up
        '';
        postStop = ''
          ip link set "${interface}" down || true
          ip link del "${interface}" || true
        '';
      };
    })
    // lib.flip lib.mapAttrs' (lib.filterAttrs (k: v: v.rules != [ ]) cfg.networkNamespaces) (name: value: let
      args = x: if builtins.isList x.extraArgs then lib.escapeShellArgs (map toString x.extraArgs) else x.extraArgs;
    in {
      name = "netns-rules-${name}";
      value = {
        description = "Network Namespace rules for ${name}";
        before = [ "network-pre.target" ];
        wants = [ "network-pre.target" ];
        bindsTo = [ "netns-${name}.service" ];
        after = [ "netns-${name}.service" ];
        wantedBy = [ "network-setup.service" "network.target" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        serviceConfig.NetworkNamespacePath = lib.mkIf (name != "default") "/var/run/netns/${name}";
        stopIfChanged = false;
        path = [ pkgs.iproute2 ];
        script = builtins.concatStringsSep "\n" (map (rule: ''
          state="/run/nixos/network/netns_rules/${name}"
          mkdir -p $(dirname "$state")
          if out=$(ip ${if rule.ipv6 then "-6" else "-4"} rule add ${args rule} 2>&1 && echo ${lib.escapeShellArg ("ip ${if rule.ipv6 then "-6" else "-4"} rule del " + args rule)} >> "$state"); then
            echo "done"
          elif ! echo "$out" | grep "File exists" >/dev/null 2>&1; then
            echo "'ip ${if rule.ipv6 then "-6" else "-4"} rule add "${lib.escapeShellArg (args rule)}"' failed: $out"
            exit 1
          fi
        '') value.rules);
        postStop = builtins.concatStringsSep "\n" (map (rule: ''
          state="/run/nixos/network/netns_rules/${name}"
          if [ -e "$state" ]; then
            while read cmd; do
              echo -n "running rule delete command $cmd... "
              $cmd >/dev/null 2>&1 && echo "done" || echo "failed"
            done < "$state"
            rm -f "$state"
          fi
        '') value.rules);
      };
    })
    // lib.flip lib.mapAttrs' cfg.networkNamespaces (name: value: {
      name = "netns-${name}";
      value = {
        description = "Network Namespace Init for ${name}";
        before = [ "network-pre.target" ];
        wants = [ "network-pre.target" ];
        wantedBy = [ "network-setup.service" "network.target" ];
        stopIfChanged = false;
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        path = [ pkgs.iproute2 ];
        script = (if name == "default" then ''
          mkdir -p /var/run/netns
          ln -s /proc/1/ns/net /var/run/netns/default || true
        '' else ''
          ip netns add "${name}" || true
        '') + lib.optionalString (value.extraStartCommands != "") ''
          ip netns exec "${name}" ${pkgs.writeShellScript "netns-init-${name}" ''
            export PATH=$PATH:${pkgs.iproute2}/bin
            ${value.extraStartCommands}
          ''}
        '';
      } // lib.optionalAttrs (name != "default" || value.extraStopCommands != "") {
        postStop = lib.optionalString (value.extraStopCommands != "") ''
          ip netns exec "${name}" ${pkgs.writeShellScript "netns-uninit-${name}" ''
            export PATH=$PATH:${pkgs.iproute2}/bin
            ${value.extraStopCommands}
          ''}
        '' + lib.optionalString (name != "default") ''
          ip netns delete "${name}"
        '';
      };
    })
    // lib.flip lib.mapAttrs'
      (lib.filterAttrs (k: v: router-lib.requiresNetnsSetup k) cfg.interfaces)
      (interface: value: let
      escapedInterface = utils.escapeSystemdPath interface;
      isVeth = router-lib.isVethPeer interface;
      vethParent = router-lib.vethParent interface;
      peerNs = cfg.interfaces.${vethParent}.networkNamespace or null;
    in {
      name = "setup-netns-for-${escapedInterface}";
      value = router-lib.mkServiceForIf' (
        # require rather than bind
        # because as soon as we move the interface, it's gone from the service's namespace
        # and bind would stop the service immediately
        if isVeth then { interface = vethParent; bindType = "requires"; } else { inherit interface; preNetns = true; bindType = "requires"; }
      ) {
        description = "Network Namespace configuration of ${interface}";
        wantedBy = [ "network-setup.service" "network.target" ];
        before = [ "network-setup.service" ];
        after = [ "network-pre.target" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        stopIfChanged = false;
        path = [ pkgs.iproute2 ];
        script = ''
          ip link set "${interface}" netns "${value.networkNamespace}"
        '';
        preStop = if isVeth then ''
          ip netns exec "${value.networkNamespace}" ip link set "${interface}" netns "${if peerNs != null then peerNs else "1"}"
        '' else ''
          ip netns exec "${value.networkNamespace}" ip link set "${interface}" netns 1
        '';
      };
    }) 
    // builtins.zipAttrsWith (k: builtins.head) (lib.flip lib.mapAttrsToList
      (lib.filterAttrs (_: hasNftablesRules) cfg.networkNamespaces)
      (name: value: {
        "nftables-netns-${name}" = {
          description = "nftables firewall for network namespace ${name}";
          wantedBy = [ "network.target" ];
          before = [ "network-setup.service" ];
          after = [ "network-pre.target" "netns-${name}.service" ];
          bindsTo = [ "netns-${name}.service" ];
          script = mkNftStartCmd value;
          reload = mkNftStartCmd value;
          preStop = mkNftStopCmd value;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            NetworkNamespacePath = "/var/run/netns/${name}";
          };
          reloadIfChanged = true;
        };
      })
    )
    // {
      network-setup = {
        partOf = map (name: "network-addresses-${utils.escapeSystemdPath name}.service") (builtins.attrNames cfg.interfaces);
      };
    };
    systemd.network.links = lib.flip lib.mapAttrs' cfg.interfaces (name: value: {
      name = "40-${name}";
      value = {
        matchConfig =
          if value.systemdLinkMatchConfig == { }
          then { OriginalName = name; }
          else value.systemdLinkMatchConfig;
        linkConfig = value.systemdLinkLinkConfig;
      };
    });
    networking.useDHCP = lib.mkIf (builtins.any (x: x.dhcpcd.enable) (builtins.attrValues cfg.interfaces)) false;
  }
  {
    systemd.services = builtins.zipAttrsWith (k: builtins.head) (builtins.concatLists (lib.mapAttrsToList (interface: icfg: map (service: {
      ${service.service or service} =
        if builtins.isString service then router-lib.mkServiceForIf interface { }
        else router-lib.mkServiceForIf' (builtins.removeAttrs service [ "service" ] // { inherit interface; }) { };
    }) icfg.dependentServices) cfg.interfaces));
  }
  (lib.mkIf config.networking.nftables.enable {
    # a stub for compatibility with services that depend on networking.nftables
    systemd.services.nftables = lib.mkForce {
      description = "nftables stub";
      bindsTo = [ "nftables-netns-default.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      serviceConfig.ExecStart = "${pkgs.coreutils}/bin/true";
    };
    router.networkNamespaces.default = let
      inherit (config.networking.nftables) ruleset rulesetFile;
    in lib.mkIf (rulesetFile != null || ruleset != "") {
      nftables.textRules = lib.mkIf (rulesetFile == null) ruleset;
      nftables.textFile = lib.mkIf (rulesetFile != null) rulesetFile;
    };
  }) ]);
}
