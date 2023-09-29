## router\.enable



Whether to enable router config\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.bridges

bridge config



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.bridges\.\<name>\.vlans



VLANs to add to this bridge



*Type:*
attribute set of list of (submodule)



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.bridges\.\<name>\.vlans\.\<name>\.\*\.untagged



should this match untagged traffic



*Type:*
boolean



*Default:*
` false `

*Declared by:*
 - [default\.nix](default.nix)



## router\.bridges\.\<name>\.vlans\.\<name>\.\*\.vid



VLAN id



*Type:*
signed integer

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces



All interfaces managed by nixos-router



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.bridge



Add this device to this bridge



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.dependentServices



Patch those systemd services to depend on this interface



*Type:*
list of (string or (attribute set))



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.dhcpcd



dhcpcd options



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.dhcpcd\.enable



Whether to enable dhcpcd (this option disables networking\.useDHCP)\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.dhcpcd\.extraConfig



dhcpcd text config



*Type:*
strings concatenated with “\\n”



*Default:*
` "" `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.hostapd



hostapd options



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.hostapd\.enable



Whether to enable hostapd\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.hostapd\.settings



hostapd config



*Type:*
attribute set



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4



IPv4 config



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.enableForwarding



Whether to enable Enable IPv4 forwarding for this device\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.addresses



Device’s IPv4 addresses



*Type:*
list of (submodule)



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.addresses\.\*\.address



IPv4 address



*Type:*
string matching the pattern ((25\[0-5]|(2\[0-4]|10|1?\[1-9])?\[0-9])\\\.){3}(25\[0-5]|(2\[0-4]|10|1?\[1-9])?\[0-9])

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.addresses\.\*\.assign



Whether to assign this address to the device\. Default: no if the first hextet is zero, yes otherwise\.



*Type:*
null or boolean



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.addresses\.\*\.dns



IPv4 DNS servers associated with this device



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.addresses\.\*\.gateways



IPv4 gateway addresses (optional)



*Type:*
null or (list of string)



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.addresses\.\*\.keaSettings



Kea IPv4 prefix-specific settings



*Type:*
JSON value



*Default:*
` { } `



*Example:*

```
{
  option-data = [
    {
      code = 6;
      csv-format = true;
      data = "8.8.8.8, 8.8.4.4";
      name = "domain-name-servers";
      space = "dhcp4";
    }
  ];
  pools = [
    {
      pool = "192.168.1.15 - 192.168.1.200";
    }
  ];
}
```

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.addresses\.\*\.prefixLength



IPv4 prefix length



*Type:*
signed integer

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.kea



Kea options



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.kea\.enable



Whether to enable Kea for IPv4\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.kea\.configFile



Kea config file (takes precedence over settings)



*Type:*
null or path



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.kea\.extraArgs



List of additional arguments to pass to the daemon\.



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.kea\.settings



Kea settings



*Type:*
JSON value



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.routes



IPv4 routes added when this device starts



*Type:*
list of (submodule)



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.routes\.\*\.extraArgs



Route args, i\.e\. everything after “ip route add”



*Type:*
string or list of anything

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv4\.rpFilter



rp_filter value for this device (see kernel docs for more info)



*Type:*
null or signed integer



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6



IPv6 config



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.enableForwarding



Whether to enable Enable IPv6 forwarding for this device\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses



Device’s IPv6 addresses



*Type:*
list of (submodule)



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses\.\*\.address



IPv6 address



*Type:*
string matching the pattern (\[1-9a-f]\[0-9a-f]{0,3}:|0:){7}(:|(\[1-9a-f]\[0-9a-f]{0,3}|0))|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){6}:(\[1-9a-f]\[0-9a-f]{0,3}|0)?|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){5}(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,2})|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){4}(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,3})|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){3}(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,4})|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){2}(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,5})|(\[1-9a-f]\[0-9a-f]{0,3}|0):(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,6})|:(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,7})

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses\.\*\.assign



Whether to assign this address to the device\. Default: no if the first hextet is zero, yes otherwise



*Type:*
null or boolean



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses\.\*\.coreradSettings



CoreRAD prefix-specific settings



*Type:*
TOML value



*Default:*
` { } `



*Example:*

```
{
  autonomous = true;
  on_link = true;
}
```

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses\.\*\.dns



IPv6 DNS servers associated with this device



*Type:*
list of (string or (submodule))



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses\.\*\.gateways



IPv6 gateways information (optional)



*Type:*
list of (string matching the pattern (\[1-9a-f]\[0-9a-f]{0,3}:|0:){7}(:|(\[1-9a-f]\[0-9a-f]{0,3}|0))|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){6}:(\[1-9a-f]\[0-9a-f]{0,3}|0)?|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){5}(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,2})|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){4}(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,3})|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){3}(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,4})|(\[1-9a-f]\[0-9a-f]{0,3}:|0:){2}(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,5})|(\[1-9a-f]\[0-9a-f]{0,3}|0):(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,6})|:(:|(:\[1-9a-f]\[0-9a-f]{0,3}|:0){1,7}) or (submodule))



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses\.\*\.keaSettings



Kea prefix-specific settings



*Type:*
JSON value



*Default:*
` { } `



*Example:*

```
{
  option-data = [
    {
      code = 23;
      csv-format = true;
      data = "aaaa::, bbbb::";
      name = "dns-servers";
      space = "dhcp6";
    }
  ];
  pools = [
    {
      pool = "fd01:: - fd01::ffff:ffff:ffff:ffff";
    }
  ];
}
```

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses\.\*\.prefixLength



IPv6 prefix length



*Type:*
signed integer

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.addresses\.\*\.radvdSettings



radvd prefix-specific settings



*Type:*
attribute set of (boolean or string or signed integer)



*Default:*
` { } `



*Example:*

```
{
  AdvAutonomous = true;
  AdvOnLink = true;
  Base6to4Interface = "ppp0";
}
```

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.corerad



CoreRAD options



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.corerad\.enable



Whether to enable CoreRAD\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.corerad\.configFile



CoreRAD config file (takes precedence over settings)



*Type:*
null or path



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.corerad\.interfaceSettings



CoreRAD interface-specific settings



*Type:*
TOML value



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.corerad\.settings



General CoreRAD settings



*Type:*
TOML value



*Default:*
` { } `



*Example:*

```
{
  debug = {
    address = "localhost:9430";
    prometheus = true;
  };
}
```

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.kea



Kea options



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.kea\.enable



Whether to enable Kea for IPv6\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.kea\.configFile



Kea config file (takes precedence over settings)



*Type:*
null or path



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.kea\.extraArgs



List of additional arguments to pass to the daemon\.



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.kea\.settings



Kea settings



*Type:*
JSON value



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.radvd



radvd options



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.radvd\.enable



Whether to enable radvd\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.radvd\.interfaceSettings



radvd interface-specific settings



*Type:*
attribute set of (boolean or string or signed integer)



*Default:*
` { } `



*Example:*

```
{
  UnicastOnly = true;
}
```

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.routes



IPv6 routes added when this device starts



*Type:*
list of (submodule)



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.ipv6\.routes\.\*\.extraArgs



Route args, i\.e\. everything after “ip route add”



*Type:*
string or list of anything

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.networkNamespace



Network namespace name to create this device in



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.systemdLink\.linkConfig



This device’s systemd\.link(5) link config



*Type:*
attribute set



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.interfaces\.\<name>\.systemdLink\.matchConfig



This device’s systemd\.link(5) match config



*Type:*
attribute set



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces



Network namespace config (default = default namespace)



*Type:*
attribute set of (submodule)

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.extraStartCommands



Start commands for this namespace\.



*Type:*
strings concatenated with “\\n”



*Default:*
` "" `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.extraStopCommands



Stop commands for this namespace\.



*Type:*
strings concatenated with “\\n”



*Default:*
` "" `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables



Per-namespace nftables rules\.



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables\.jsonFile



JSON rules file to run on namespace start\.



*Type:*
null or path



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables\.jsonRules



JSON rules to run on namespace start\.



*Type:*
null or JSON value



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables\.stopJsonFile



JSON rules file to run on namespace stop *and before the first start*\.



*Type:*
null or path



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables\.stopJsonRules



JSON rules to run on namespace stop *and before the first start*\.



*Type:*
null or JSON value



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables\.stopTextFile



Text rules file to run on namespace stop *and before the first start*\. Make sure to set this to “flush ruleset” if you want to reset the old rules!



*Type:*
null or path



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables\.stopTextRules



Text rules to run on namespace stop *and before the first start*\. Make sure to add “flush ruleset” as the first line if you want to reset old rules!



*Type:*
null or strings concatenated with “\\n”



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables\.textFile



Text rules file to run on namespace start\.



*Type:*
null or path



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.nftables\.textRules



Text rules to run on namespace start\. Make sure to add “flush ruleset” as the first line if you want to reset old rules!



*Type:*
null or strings concatenated with “\\n”



*Default:*
` null `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.rules



IP routing rules added when this network namespace starts



*Type:*
list of (submodule)



*Default:*
` [ ] `

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.rules\.\*\.extraArgs



Rule args, i\.e\. everything after “ip rule add”



*Type:*
string or list of anything

*Declared by:*
 - [default\.nix](default.nix)



## router\.networkNamespaces\.\<name>\.rules\.\*\.ipv6



Whether this rule is ipv6



*Type:*
boolean

*Declared by:*
 - [default\.nix](default.nix)



## router\.veths



veth pairs



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [default\.nix](default.nix)



## router\.veths\.\<name>\.peerName



Name of veth peer (the second veth device created at the same time)



*Type:*
unspecified value

*Declared by:*
 - [default\.nix](default.nix)


