{ lib
, config ? null
, utils ? null
, ...
}:

let
  cfg = config.router;
  vethParents = lib.mapAttrs'
    (name: value: {
      name = value.peerName;
      value = name;
    })
    cfg.veths;
  bridges = builtins.zipAttrsWith
    (k: builtins.filter (x: x != null))
    (builtins.filter (x: x != null)
      (lib.mapAttrsToList
        (interface: icfg: if icfg.bridge == null then null else {
          ${icfg.bridge.name} = if icfg.hostapd.enable then null else interface;
        })
        cfg.interfaces));
  # finds the longest zero-only sequence in a parsed IPv6
  # returns an attrset with maxStart (start of the sequence) and maxLen (sequence length)
  longestZeroSeq =
    lib.flip builtins.foldl' { } ({ curLen ? 0, maxLen ? 0, curStart ? -1, maxStart ? -1, i ? 0 }: n:
      let
        updateCur = n == 0;
        newCurLen = if updateCur then curLen + 1 else 0;
        # prefer :: in the middle, as it saves more space (a::b vs ::a:b/a:b::)
        updateMax = newCurLen > maxLen || (maxLen == newCurLen && maxStart <= 0);
        newCurStart = if updateCur then (if curStart == -1 then i else curStart) else -1;
      in
      {
        i = i + 1;
        curLen = newCurLen;
        curStart = newCurStart;
        maxLen = if updateMax then newCurLen else maxLen;
        maxStart = if updateMax then newCurStart else maxStart;
      });
in
lib.optionalAttrs (config != null && utils != null)
  rec {
    isVethPeer = interface: vethParents?${interface};
    vethParent = interface: vethParents.${interface} or null;

    # interface is virtual and managed by nixos-router
    ifIsVirtualRouter = interface:
      bridges?${interface}
      || cfg.veths?${interface}
      || vethParents?${interface};
    # interface is virtual and managed by nixos
    ifIsVirtualNixos = interface:
      (lib.filterAttrs (k: v: v.virtual) config.networking.interfaces)?${interface}
      || config.networking.bridges?${interface}
      || config.networking.bonds?${interface}
      || config.networking.macvlans?${interface}
      || config.networking.sits?${interface}
      || config.networking.vlans?${interface}
      || config.networking.vswitches?${interface};
    # interface is virtual
    ifIsVirtual = interface: ifIsVirtualRouter interface || ifIsVirtualNixos interface;

    requiresNetnsSetup = interface:
      if vethParents?${interface} then
        (cfg.interfaces.${vethParents.${interface}}.networkNamespace or null) != (cfg.interfaces.${interface}.networkNamespace or null)
      else
        !(ifIsVirtualRouter interface) && (cfg.interfaces.${interface}.networkNamespace or null) != null;

    mainDepForIf = interface: mainDepForIf' { inherit interface; };
    mainDepForIf' = { interface, preNetns ? false, inNetns ? !preNetns, ... }:
      let
        netns = cfg.interfaces.${interface}.networkNamespace or null;
        # if device is in a netns, systemd wont see the sys-subsystem-net-devices unit
        # instead, we depend on the service that moves the device into the target namespace
      in
      if !preNetns && netns != null && requiresNetnsSetup interface then
        "setup-netns-for-${utils.escapeSystemdPath interface}.service"
      # or if it's a virtual device, we can just depend on the device configuration service
      else if ifIsVirtual interface then
        "${utils.escapeSystemdPath (vethParents.${interface} or interface)}-netdev.service"
      # finally, for non-virtual devices in the default namespace, use systemd subsystem device
      else "sys-subsystem-net-devices-${utils.escapeSystemdPath interface}.device";

    # create a service that expects to run alongside the interface `name`
    mkServiceForIf = interface: mkServiceForIf' { inherit interface; };
    # `attrs` is the actual service config which this function extends
    # includeBasicDeps = actually depend on the interface, rather than just the netns
    # preNetns = run before the network namespace is applied (no guarantees, used internally)
    # inNetns = run in the device's network namespace (true by default)
    # bindType = where to put the dependencies (bindsTo by default)
    mkServiceForIf' = args0@{ interface, includeBasicDeps ? true, preNetns ? false, inNetns ? !preNetns, bindType ? "bindsTo" }: attrs:
      let
        netns = cfg.interfaces.${interface}.networkNamespace or null;
        deps =
          lib.optional includeBasicDeps (mainDepForIf' args0)
          # dont forget that we need the device's network namespace to be active
          ++ lib.optional (netns != null) "netns-${netns}.service";
      in
      attrs // {
        after = attrs.after or [ ] ++ deps;
        ${bindType} = attrs.${bindType} or [ ] ++ deps;
        serviceConfig = attrs.serviceConfig or { }
        // lib.optionalAttrs (inNetns && netns != null) {
          NetworkNamespacePath = "/var/run/netns/${netns}";
        };
      };
  } // rec {
  # parses a hexadecimal number
  parseHex = x: (builtins.fromTOML "x=0x${x}").x;
  # parses a binary number
  parseBin = x: (builtins.fromTOML "x=0b${x}").x;
  # parses a decimal number
  parseDec = builtins.fromJSON;

  # zip attrs, taking one attr value for each key
  zipHeads = builtins.zipAttrsWith (_: builtins.head);

  # generate 0b11111...
  gen1Bits = count:
    if count == 0 then 0 else (gen1Bits (count - 1)) * 2 + 1;
  lshift = a: b: if b == 0 then a else lshift (a * 2) (b - 1);
  rshift = a: b: if b == 0 then a else rshift (a / 2) (b - 1);
  # generate an integer of `total` bits with `set` most significant bits set
  genIntMask = total: set: lshift (gen1Bits set) (total - set);

  # generate subnet mask for ipv4 (not serialized)
  genMask4 = prefixLength:
    builtins.genList
      (i:
        let
          len = prefixLength - i * 8;
        in
        if len <= 0 then 0
        else if len >= 8 then 255
        else genIntMask 8 len) 4;
  # generate subnet mask for ipv6 (not serialized)
  genMask6 = prefixLength:
    builtins.genList
      (i:
        let
          len = prefixLength - i * 16;
        in
        if len <= 0 then 0
        else if len >= 16 then 65535
        else genIntMask 16 len) 8;

  # invert a mask
  invMask4 = map (builtins.bitXor 255);
  invMask6 = map (builtins.bitXor 65535);
  invMask = mask: (if builtins.length mask == 4 then invMask4 else invMask6) mask;

  # deserialized mask operations
  orMask = lib.zipListsWith builtins.bitOr;
  andMask = lib.zipListsWith builtins.bitAnd;

  # serialized mask operations
  # applyMask - throw away any bits after prefixLength
  applyMask = { address, prefixLength }:
    let
      parsed = parseIp address;
      subnetMask = (if builtins.length parsed == 4 then genMask4 else genMask6) prefixLength;
    in
    {
      address = serializeIp (andMask subnetMask parsed);
      inherit prefixLength;
    };

  ip4Regex =
    let
      compRegex = "(25[0-5]|(2[0-4]|10|1?[1-9])?[0-9])";
    in
    "(${compRegex}\\.){3}${compRegex}";

  cidr4Regex = "${ip4Regex}/(3[0-2]|[1-2]?[0-9])";

  ip6Regex =
    let
      compRegex = "([1-9a-f][0-9a-f]{0,3}|0)";
      compStartRegex = "([1-9a-f][0-9a-f]{0,3}:|0:)";
      compEndRegex = "(:[1-9a-f][0-9a-f]{0,3}|:0)";
      # exactly n components with trailing :
      compStartExact = n:
        if n == 1 then "${compRegex}:"
        else "${compStartRegex}{${toString n}}";
      compEndUpTo = n:
        if n == 1 then ":${compRegex}?"
        else "(:|${compEndRegex}{1,${toString n}})";
    in
    builtins.concatStringsSep "|" [
      # the end is either :: or :${compRegex}
      "${compStartExact 7}(:|${compRegex})"
      # there's :: in the middle
      (compStartExact 6 + compEndUpTo 1)
      (compStartExact 5 + compEndUpTo 2)
      (compStartExact 4 + compEndUpTo 3)
      (compStartExact 3 + compEndUpTo 4)
      (compStartExact 2 + compEndUpTo 5)
      (compStartExact 1 + compEndUpTo 6)
      # there's :: at the start
      (":" + compEndUpTo 7)
    ];

  cidr6Regex = "(${ip6Regex})/(12[0-8]|(1[01]|[1-9]?)[0-9])";

  types = {
    ipv4 = lib.types.strMatching ip4Regex;
    ipv6 = lib.types.strMatching ip6Regex;
    cidr4 = lib.types.strMatching cidr4Regex;
    cidr6 = lib.types.strMatching cidr6Regex;
  };

  # parses an IPv4 address into an array of integers
  parseIp4 = s: map parseDec (lib.splitString "." s);
  # serializes an IPv4 address
  serializeIp4 = ip: builtins.concatStringsSep "." (map toString ip);

  # parses an IPv6 address
  parseIp6 = s:
    let
      # parts before and after ::
      halves = map (x: if x == "" then [ ] else map parseHex (lib.splitString ":" x)) (lib.splitString "::" s);
      a = builtins.head halves;
      b = if builtins.length halves == 1 then [ ] else builtins.elemAt halves 1;
    in
    a ++ (builtins.genList (_: 0) (8 - builtins.length a - builtins.length b)) ++ b;

  # serializes an IPv6 address
  serializeIp6 = ip:
    let
      # find longest sequence of zeroes in the IP (max = length, maxS = start)
      inherit (longestZeroSeq ip) maxLen maxStart;
      hextets = map (x: lib.toLower (lib.toHexString x)) ip;
      join = builtins.concatStringsSep ":";
    in
    if maxStart == -1 then join hextets
    else join (lib.take maxStart hextets) + "::" + join (lib.drop (maxStart + maxLen) hextets);

  parseIp = s: if lib.hasInfix ":" s then parseIp6 s else parseIp4 s;
  serializeIp = x: (if builtins.length x == 4 then serializeIp4 else serializeIp6) x;

  # returns { address, prefixLength }
  parseCidr = cidr:
    let split = lib.splitString "/" cidr; in {
      address = builtins.head split;
      prefixLength = parseDec (builtins.elemAt split 1);
    };
  serializeCidr = { address, prefixLength }: "${address}/${toString prefixLength}";

  # zeroes out everything past prefixLength
  normalizeCidr = { address, prefixLength }:
    let
      parsed = parseIp address;
      mask = (if builtins.length parsed == 4 then genMask4 else genMask6) prefixLength;
    in
    {
      address = serializeIp (lib.zipListsWith builtins.bitAnd parsed mask);
      inherit prefixLength;
    };
}
