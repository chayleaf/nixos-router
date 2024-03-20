{ lib
, config
, pkgs
, utils
, router-lib
, ...
}:

let
  cfg = config.router;
  hostapd = pkgs.hostapd;
in
{
  config = lib.mkIf (cfg.enable && builtins.any (x: x.hostapd.enable) (builtins.attrValues cfg.interfaces)) {
    environment.systemPackages = [ hostapd ] ++ (with pkgs; [ wirelesstools ]);
    hardware.wirelessRegulatoryDatabase = true;
    systemd.services = lib.flip lib.mapAttrs' cfg.interfaces (interface: icfg:
      let
        escapedInterface = utils.escapeSystemdPath interface;
        compileValue = k: v:
          if builtins.isBool v then (if v then "1" else "0")
          else if builtins.isList v then builtins.concatStringsSep " " (map (compileValue k) v)
          else if k == "ssid2" then "P${builtins.toJSON (toString v)}"
          else toString v;
        compileSettings = x:
          let
            y = builtins.removeAttrs x [ "ssid" ];
            z = if y?ssid2 then y else y // { ssid2 = x.ssid; };
          in
          if !x?ssid && !x?ssid2 then
            throw "Must specify ssid for hostapd"
          else if x.wpa_key_mgmt == defaultSettings.wpa_key_mgmt && !x?wpa_passphrase && !x?sae_password then
            throw "Either change authentication methods or specify wpa_passphrase for hostapd"
          else builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${compileValue k v}") z);
        forceSettings = {
          inherit interface;
        };
        defaultSettings = {
          driver = "nl80211";
          logger_syslog = -1;
          logger_syslog_level = 2;
          logger_stdout = -1;
          logger_stdout_level = 2;
          # not sure if enabling it when it isn't supported is gonna break anything?
          ieee80211n = true; # wifi 4
          ieee80211ac = true; # wifi 5
          ieee80211ax = true; # wifi 6
          # ieee80211be = true; # wifi 7
          ctrl_interface = "/run/hostapd";
          disassoc_low_ack = true;
          wmm_enabled = true;
          uapsd_advertisement_enabled = true;
          utf8_ssid = true;
          sae_require_mfp = true;
          ieee80211w = 1; # optional mfp
          sae_pwe = 2;
          auth_algs = 1;
          wpa = 2;
          wpa_pairwise = [ "CCMP" ];
          wpa_key_mgmt = [ "WPA-PSK" "WPA-PSK-SHA256" "SAE" ];
          okc = true;
          group_mgmt_cipher = "AES-128-CMAC";
          qos_map_set = "0,0,2,16,1,1,255,255,18,22,24,38,40,40,44,46,48,56"; # from openwrt
          # ap_isolate = true; # to isolate clients
        } // lib.optionalAttrs (icfg.hostapd.settings?country_code) {
          ieee80211d = true;
        } // lib.optionalAttrs (icfg.bridge != null) {
          bridge = icfg.bridge.name;
        };
        settings = defaultSettings // icfg.hostapd.settings // forceSettings;
        configFile = pkgs.writeText "hostapd.conf" (compileSettings settings);
      in
      {
        name = "hostapd-${escapedInterface}";
        value = lib.mkIf icfg.hostapd.enable (router-lib.mkServiceForIf interface rec {
          description = "hostapd wireless AP (${interface})";
          path = [ hostapd ];
          after = lib.optional (settings.bridge != null) (router-lib.mainDepForIf settings.bridge);
          bindsTo = after;
          requiredBy = [ "network-link-${escapedInterface}.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${hostapd}/bin/hostapd ${configFile}";
            Restart = "always";
          };
        });
      });
  };
}
