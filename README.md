# nixos-router

This project has an ambitious goal of creating a framework for writing
NixOS router configurations - in other words, being the
[simple-nixos-mailserver](https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/)
of the networking world, but without the "simple" part, because
networking is hard. This may include complex features like running
multiple DHCP servers, using network namespaces, having interfaces turn
on and off while the rest of the system keeps working, etc.

Sadly, NixOS is written without such requirements in mind. That means
this project has to create the code from scratch. This is both a
blessing and a curse - we can't reuse the existing code, but we can
write new, better code that is more flexible.

That said, I'm not using this at an enterprise or an ISP, this is simply
for my home router config (yes, overkill, I know). So this is bound to
not fit everybody's needs right now. Obviously, I'm willing to add more
features even at the cost of breaking existing configs if necessary
(after all, this project is in its infancy).

I'll try to keep breaking changes to a minimum, but as I said, I can't
guarantee they won't happen (even NixOS has them).

Use the 23.11 branch for NixOS 23.11. I'll backport what I can to it.
For nixos-unstable, use the master branch.

I doubt it would be easy to upstream these changes to nixpkgs, as it
would introduce many breaking changes on top of breaking changes, so I
am not willing to work on it. Some parts are more upstreamable, such as
allowing JSON nftables rulesets, while other are less upstreamable,
like... most parts of this repo, which are a reimplementation of
scripted networking, which some nixpkgs members want to get rid of in
general (in favor of systemd-networkd).

When [this](https://github.com/systemd/systemd/issues/11103) gets
closed, I might be able to migrate to systemd-networkd. This may be the
time when `networking.interfaces` and this repo become compatible again.

This module expects you to use nftables, so it modifies NixOS's default
settings to use nftables. Firewall is still set to use iptables, but if
you set `networking.nftables.enable` to `true`, it should use nftables.

## Roadmap

I think the next logical step for this project is adding nftables
options for common scenarios like NAT, so this is what I want to do
next. Right now you're expected to create the nftables rules from
scratch, but something like `networking.nat` (but with more
customizability) could be nice. Another potential way to improve this is
adding the missing virtual device types (currently only bridges and veth
pairs are supported; `networking` has bridge, bond, MacVLAN, 6-to-4,
VLAN, Open vSwitch device support).

## See also

- [notnft](https://github.com/chayleaf/notnft) - a Nix DSL for writing
  JSON nftables rules. If you use the included NixOS module, it is
  automatically used for type checking JSON nftables rules.
- [My router
  config](https://github.com/chayleaf/dotfiles/blob/master/system/hosts/router/default.nix)
  using this framework.

## Options

See [the wiki](https://github.com/chayleaf/nixos-router/wiki/Options)
for an automatically built option list. This is a manually condensed
version of the option list.

- `router.enable` - whether to do anything at all
- `router.networkNamespaces` - per-network namespace config.
  - A special namespace `default` is available for configuring the
    default namespace.
  - `<namespace>.extraStartCommands` - extra commands to execute at
    network namespace start
  - `<namespace>.extraStopCommands` - extra commands to execute at
    network namespace stop
  - `<namespace>.rules` - IP routing rules to add for this namespace via
    `ip rule`
      - `<route>.ipv6` - whether this rule is an IPv6 rule
      - `<route>.extraArgs` - arguments to pass to the `ip rule`
        command. May be a list or a string.
  - `<namespace>.nftables` - nftables config to run in this namespace
    (see `router.nftables` for options)
    - Difference from `networking.nftables` - this supports JSON
      rulesets, and lets you specify custom stop/reload rules, while
      `networking.nftables` always flushes the ruleset on stop. Also, it
      supports loading static rules and file-based rules at the same
      time. One-way `networking.nftables` operability is supported.
    - `<namespace>.nftables.textFile` - `.nft` file to load
    - `<namespace>.nftables.textRules` - nft rules to load
    - `<namespace>.nftables.jsonFile` - `.json` file to load
    - `<namespace>.nftables.jsonRules` - JSON rules to load
    - `<namespace>.nftables.{stopTextFile,stopTextRules,stopJsonFile,stopJsonRules}` -
      same as above, but get executed *before first start* and at
      stop/reload time. Basically, they are supposed to undo the changes
      this ruleset applies, or do nothing if it's not applied anyway.
      They default to `flush ruleset` if no stop rules are set.
- `router.veths.<name>` - veth pairs
  - `<veth>.peerName` - peer name (second device to be created at the
    same time)
- `router.interfaces.<name>` - per-interface config
  - Difference from `networking.interfaces` - it's just subtly
    different... Many features were added that `networking.interfaces`
    is incompatible with. This means you can't use it together with
    `networking.interfaces`, as both `router.interfaces` and
    `networking.interfaces` expect having to set the interfaces up.
  - `<iface>.bridge` - bridge name to enslave this device to
  - `<iface>.vlans.*` - VLAN filtering configuration
    - `<vlan>.vid` - VLAN id filter
    - `<vlan>.untagged` - whether this should match untagged traffic
      (defaults to false)
  - `<iface>.extraInitCommands` - extra commands to execute before
    bridge/address configuration
  - `<iface>.networkNamespace` - the network namespace where this device
    and all dependent services will run
  - `<iface>.dependentServices` - services that should depend on this
    interface
    - each is either a string (service name) or an attrset with the key
      `service` and the rest being attrs to to pass to
      `router-lib.mkServiceForIf'`, for example, you can set `inNetns`
      to false to not use this interface's network namespace.
  - `<iface>.systemdLink.linkConfig` - values to add to
    [systemd.link(5)](https://www.freedesktop.org/software/systemd/man/systemd.link.html)
    `[Link]` config for this interface
  - `<iface>.systemdLink.matchConfig` - values to add to
    [systemd.link(5)](https://www.freedesktop.org/software/systemd/man/systemd.link.html)
    `[Match]` config for this interface. Defaults to `{ OriginalName =
    "<interface name>"; }`
  - `<iface>.hostapd` - run hostapd to turn this device into a wireless
    access point
    - `<iface>.hostapd.enable` - enable hostapd
    - `<iface>.hostapd.settings` - hostapd settings (attrset). See
      example
      [hostapd.conf](https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf)
      for a list of options. Personally, I copied OpenWRT configs for
      my router.
    - There's a way to host multiple ssids on a single interface in
      hostapd (on supported interfaces), this module doesn't currently
      support it
  - `<iface>.dhcpcd` - run `dhcpcd` on this interface.
    - The reasons for adding it here:
      - `dhcpcd` may fail in rare cases when not specifing the interface
        list in the command line, which I do here.
      - Strong caution is needed when running a single `dhcpcd` on many
        interfaces, as settings may "leak" into other interfaces.
        Example of an option you need to be careful with is IPv6 router
        solicitation (ipv6rs).
    - `<iface>.dhcpcd.enable` - enable dhcpcd on this interface
    - `<iface>.dhcpcd.extraConfig` - extra text config for dhcpcd
  - `<iface>.ipv4` - IPv4-specific config:
    - `<iface>.ipv4.enableForwarding` - sets `forwarding` sysctl for
      this device so it can forward packets it receives.
    - `<iface>.ipv4.rpFilter` - set `rp_filter` value for this device to
      check reverse path and block non-existent IPs (value 2) or IPs
      coming from the wrong interfaces (value 1). Alternatively, you can
      ignore this and query fib in nftables.
    - `<iface>.ipv4.addresses` - IPv4 addresses of this device
      - `<addr>.address` - the address
      - `<addr>.prefixLength` - network prefix length
      - `<addr>.assign` - whether to actually assign the address to this
        device (defaults to `false` if the first octet is zero and
        `true` otherwise). If not, it will simply be used as default
        value for service config.
      - `<addr>.gateways` - for DHCP servers - the IPv4 gateways for
        this network. If not set, `address` is used as the sole gateway.
      - `<addr>.dns` - for DHCP servers - IPv4 DNS servers for this
        network.
      - `<addr>.keaSettings` - prefix-specific Kea settings (only used
        if Kea is enabled). `pools` has sane defaults (reserve 16
        addresses before and after the interface address and
        before and after prefix start/end, make the rest available
        for DHCP clients), `option-data` defaults to whatever you
        set in `gateways` and `dns`. If you want to unset those
        settings, overwrite `pools` and `option-data` with empty
        (or non-empty) lists.
    - `<iface>.ipv4.routes` - List of IPv4 route to add when this device
      is online.
      - `<route>.extraArgs` - arguments to pass to the `ip -4 add`
        command. May be a list or a string.
      - There is no other options for `routes`, that's it.
    - `<iface>.ipv4.kea` - Kea settings (maintained replacement for
      dhcpd)
      - `<iface>.ipv4.kea.enable` - enable Kea
      - `<iface>.ipv4.kea.extraArgs` - extra args to pass to Kea
      - `<iface>.ipv4.kea.configFile` - Kea config file (if this is set,
        all other Kea settings are ignored)
      - `<iface>.ipv4.kea.settings` - Kea settings. Defaults to one
        `subnet4` (see `addresses.keaSettings` for a way to configure
        it), `valid-lifetime = 4000`, `lease-database` set to a file at
        `/var/lib/kea/dhcp4-${interface}.leases`, and obviously
        `interfaces-config` set. You may overwrite any of it.
  - `<iface>.ipv6` - IPv6-specific config:
    - `<iface>.ipv6.enableForwarding` - sets `forwarding` sysctl for
      this device so it can forward packets it receives. Obviously,
      you better setup a firewall if you do this.
    - `<iface>.ipv6.addresses` - List of IPv6 addresses of this device
      - `<addr>.address` - the address
      - `<addr>.prefixLength` - network prefix length
      - `<addr>.assign` - whether to actually assign the address to this
        device (defaults to `false` if the first octet is zero and
        `true` otherwise). Otherwise, it will simply be used as
        default value for service config.
      - `<addr>.gateways` - for DHCP servers - the IPv6 gateways for
        this network. If empty, I don't know what happens, you guess.
        - Each gateway may be a string in the CIDR notation.
          Alternatively, it may be an attrset with the following
          attrs:
        - `<gateway>.address` - the address
        - `<gateway>.prefixLength` - network prefix length
        - `<gateway>.radvdSettings` - radvd `route` settings for this
          gateway (attrset)
        - `<gateway>.coreradSettings` - CoreRAD `route` settings for
          this gateway (attrset)
      - `<addr>.dns` - for DHCP servers - IPv6 DNS servers for this
        network.
        - Each DNS server may be a string (the DNS address).
          Alternatively, if may be an attrset with the following attrs:
          - `address` - the DNS server address
          - `radvdSettings` - radvd `RDNSS` settings for this
            DNS server (attrset)
          - `coreradSettings` - CoreRAD `rdnss` settings for this
            DNS server (attrset)
      - `<addr>.keaSettings` - prefix-specific Kea settings (only used
        if Kea is enabled). `pools` has sane defaults (reserve 16
        addresses before and after the interface address and
        before and after prefix start/end, make the rest available
        for DHCP clients), `option-data` defaults to whatever you
        set in `dns`. If you want to unset it settings, overwrite
        `pools` and `option-data` with empty (or non-empty) lists.
      - `<addr>.radvdSettings` - radvd per-prefix settings (attrset).
        `AdvAutonomous` defaults to `true` if `AdvManagedFlag` is set to
        true in per-interface radvd settings.
      - `<addr>.coreradSettings` - CoreRAD per-prefix settings
        (attrset). `autonomous` defaults to `true` if `managed` is set
        to true in per-interface CoreRAD settings.
    - `<iface>.ipv6.routes` - List of IPv6 routes to add when this
      device is online.
      - `<route>.extraArgs` - arguments to pass to the `ip -6 add`
        command. May be a list or a string.
      - There is no other options for `routes`, that's it.
    - `<iface>.ipv6.kea` - Kea settings (maintained replacement for
      dhcpd)
      - `<iface>.ipv6.kea.enable` - enable Kea
      - `<iface>.ipv6.kea.extraArgs` - extra args to pass to Kea
      - `<iface>.ipv6.kea.configFile` - Kea config file (if this is set,
        all other Kea settings are ignored)
      - `<iface>.ipv6.kea.settings` - Kea settings. Defaults to one
        `subnet6` (see `addresses.*.keaSettings` for a way to configure
        it), `valid-lifetime = 4000`, `preferred-lifetime = 3000`
        `lease-database` set to a file at
        `/var/lib/kea/dhcp6-${interface}.leases`, and obviously
        `interfaces-config` set. You may overwrite any of it.
    - `<iface>.ipv6.radvd` - radvd settings (IPv6 router advertisement
      daemon)
      - `<iface>.ipv6.radvd.enable` - enable radvd
      - `<iface>.ipv6.radvd.interfaceSettings` - per-interface settings
        (attrs). Defaults to `AdvSendAdvert = true`, if any DHCP server
        (e.g. Kea) is enabled then `AdvManagedFlag` and
        `AdvOtherConfigFlag` default to true as well.
    - `<iface>.ipv6.corerad` - CoreRAD settings (IPv6 router
      advertisement daemon)
      - `<iface>.ipv6.corerad.enable` - enable radvd
      - `<iface>.ipv6.corerad.interfaceSettings` - per-interface
        settings (attrs). Defaults to `advertise = true`, if any DHCP
        server (e.g. Kea) is enabled then `managed` and `other_config`
        default to true as well.
      - `<iface>.ipv6.corerad.settings` - general CoreRAD settings
        (useful for setting `debug` options)
