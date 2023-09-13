{ lib
, config
, pkgs
, router-lib
, ... }:

let
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
    # whether to inject text file rules into the text rules
    injectTextFile = haveTextFile && haveTextRules;
    # whether to inject stop rules before start rules
    injectStopRules =
      # make sure there's exactly one set of rules to inject to,
      # since all stop rules must run before all start rules
      (haveJsonRules != haveTextRules)
      # if stop files are used, don't inject, since we can't inject anything to files
      && !haveStopTextFile && !haveStopJsonFile
      # if text/json stop rules exist, ensure the text/json start rules to inject to exist
      && (haveStopTextRules -> haveTextRules) && (haveStopJsonRules -> haveJsonRules);
    nft = "${pkgs.nftables}/bin/nft";
    fallback = d: x: if x != null then x else d;
  in ''
    ${lib.optionalString (!injectStopRules) (mkNftStopCmd attrs)}
    ${lib.optionalString (!jsonAfter && haveJsonRules) "${nft} -j ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.json";
      text = builtins.toJSON {
        nftables = (lib.optionals injectStopRules (attrs.nftables.stopJsonRules.nftables or [ { flush.ruleset = null; } ]))
                   ++ attrs.nftables.jsonRules.nftables;
      };
    }}"}
    ${lib.optionalString haveTextRules "${nft} ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.nft";
      text = (lib.optionalString injectStopRules ((fallback "flush ruleset" attrs.nftables.stopTextRules) + "\n"))
             + (lib.optionalString injectTextFile "include \"${attrs.nftables.textFile}\"\n")
             + attrs.nftables.textRules;
    }}"}
    ${lib.optionalString (haveTextFile && !injectTextFile) "${nft} ${nftFlags} -f ${attrs.nftables.textFile}"}
    ${lib.optionalString haveJsonFile "${nft} -j ${nftFlags} -f ${attrs.nftables.jsonFile}"}
    ${lib.optionalString (jsonAfter && haveJsonRules) "${nft} -j ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.json";
      text = builtins.toJSON {
        nftables = (lib.optionals injectStopRules (attrs.nftables.stopJsonRules.nftables or [ { flush.ruleset = null; } ]))
                   ++ attrs.nftables.jsonRules.nftables;
      };
    }}"}
  '';

  # TODO: remember previous deletions
  mkNftStopCmd = attrs: let
    haveStopTextFile = attrs.nftables.stopTextFile != null;
    haveStopTextRules = attrs.nftables.stopTextRules != null;
    haveStopJsonFile = attrs.nftables.stopJsonFile != null;
    haveStopJsonRules = attrs.nftables.stopJsonRules != null;
    stopRulesEmpty = !haveStopJsonRules && !haveStopTextRules && !haveStopTextFile && !haveStopJsonFile;
  in ''
    ${lib.optionalString stopRulesEmpty "${pkgs.nftables}/bin/nft ${nftFlags} flush ruleset"}
    ${lib.optionalString haveStopTextFile "${pkgs.nftables}/bin/nft ${nftFlags} -f ${attrs.nftables.stopTextFile}"}
    ${lib.optionalString haveStopTextRules "${pkgs.nftables}/bin/nft ${nftFlags} -f ${pkgs.writeTextFile {
      name = "nftables-ruleset.nft";
      text = attrs.nftables.stopTextRules;
    }}"}
    ${lib.optionalString haveStopJsonFile "${pkgs.nftables}/bin/nft -j ${nftFlags} -f ${attrs.nftables.stopJsonFile}"}
    ${lib.optionalString haveStopJsonRules "${pkgs.nftables}/bin/nft -j ${nftFlags} -f ${pkgs.writeTextFile {
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

  enableNftables = builtins.any hasNftablesRules (builtins.attrValues cfg.networkNamespaces);
in {
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # separate this out so it doesn't depend on systemHasNftables
      networking.nftables.enable = lib.mkDefault config.networking.firewall.enable;
    })
    (lib.mkIf (cfg.enable && config.networking.nftables.enable) {
      router.networkNamespaces.default = let
        inherit (config.networking.nftables) ruleset rulesetFile flushRuleset extraDeletions;
        tables = lib.filterAttrs (_: t: t.enable) config.networking.nftables.tables;
      in lib.mkIf (rulesetFile != null || ruleset != "" || tables != {}) {
        nftables.textRules = lib.mkIf (ruleset != "" || tables != {}) ''
          ${ruleset}
          ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (_: t: ''
            table ${t.family} ${t.name} {
            ${builtins.concatStringsSep "\n" (map (s: "  ${s}") (lib.splitString "\n" t.content))}
            }
          '') tables)}
        '';
        nftables.textFile = lib.mkIf (rulesetFile != null) rulesetFile;
        nftables.stopTextRules = lib.mkIf (!flushRuleset || extraDeletions != "") ''
          ${if flushRuleset then "flush ruleset"
            else builtins.concatStringsSep "\n" (lib.mapAttrsToList (_: t: ''
              table ${t.family} ${t.name}
              delete table ${t.family} ${t.name}
            '') tables)}
          ${extraDeletions}
        '';
      };
    })
    (lib.mkIf (cfg.enable && enableNftables) {
      environment.systemPackages = [ pkgs.nftables ];
      boot.blacklistedKernelModules = [ "ip_tables" ];
      # make the firewall use nftables by default
      networking.networkmanager.firewallBackend = lib.mkDefault "nftables";
      services.fail2ban.banaction = lib.mkDefault "nftables-multiport";
      services.fail2ban.banaction-allports = lib.mkDefault "nftables-allport";
      services.fail2ban.packageFirewall = lib.mkDefault pkgs.nftables;
      services.opensnitch.settings.Firewall = lib.mkDefault "nftables";
      systemd.services = 
        router-lib.zipHeads (lib.flip lib.mapAttrsToList
          (lib.filterAttrs (_: hasNftablesRules) cfg.networkNamespaces)
          (name: value: {
            "nftables-netns-${name}" = {
              description = "nftables firewall for network namespace ${name}";
              wantedBy = [ "network-online.target" ];
              before = [ "network-online.target" ];
              # only do it after all interfaces have been brought online, since
              # nftables may fail otherwise
              # XXX: is running in network-pre and restarting on fail a couple times
              #      more resilient for some configs? I don't know, so I'm leaving
              #      this "cleaner" solution here
              after = [ "network.target" "netns-${name}.service" ];
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
          }))
        // lib.optionalAttrs config.networking.nftables.enable {
          # a stub for compatibility with services that depend on networking.nftables
          nftables = lib.mkIf config.networking.nftables.enable (lib.mkForce {
            description = "nftables stub";
            bindsTo = [ "nftables-netns-default.service" ];
            serviceConfig.Type = "oneshot";
            serviceConfig.RemainAfterExit = true;
            serviceConfig.ExecStart = "${pkgs.coreutils}/bin/true";
          });
        };
    })
  ];
}
