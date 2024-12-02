{ cache-domains }: { config, lib, pkgs, ... }:
with lib;
with builtins;
let
  cfg = config.lancache.dns;

  domains = filter
    (d: d != "" && match "^#.*" d == null)
    (lib.lists.flatten (
      map
        (f: split "\n" (
          readFile (cache-domains + "/${f}")
        )
        )
        (filter (f: match ".*txt$" f != null) (attrNames (readDir cache-domains)))
    ));

  ip = cfg.cacheIp;
  ip6 = cfg.cacheIp6;
  zonefile = toFile "zonefile" (''
    $TTL    600
    @       IN  SOA ns1 dns.lancache.net. (
                ${substring 0 8 cache-domains.lastModifiedDate}
                604800
                600
                600
                600 )
    @       IN  NS  ns1
    ns1     IN  A   ${ip}

    @       IN  A   ${ip}
    *       IN  A   ${ip}

  '' + lib.optionalString (ip6!="") ''
    ns1     IN AAAA ${ip6}

    @       IN AAAA ${ip6}
    *       IN AAAA ${ip6}

  '');
in
{
  options = {
    lancache.dns = {
      enable = mkEnableOption "Enables the Lancache DNS server";
      forwarders = mkOption {
        description = "Upstream DNS servers. Defaults to CloudFlare and Google public DNS";
        type = with types; listOf str;
        default = [ "1.1.1.1" "8.8.8.8" ];
      };
      cacheIp = mkOption {
        description = "IPv4 of cache server to advertise via DNS";
        type = with types; str;
      };
      cacheIp6 = mkOption {
        description = "IPv6 of cache server to advertise via DNS";
        type = with types; str;
        default = "";
      };
      cacheNetworks = mkOption {
        description = "Subnets to listen to for DNS requests";
        type = with types; listOf str;
        default = [ "192.168.0.0/24" "127.0.0.0/24" ];
      };
    };
  };

  config = mkIf cfg.enable {
    services.bind = {
      enable = true;
      forwarders = cfg.forwarders;
      cacheNetworks = cfg.cacheNetworks;
      zones = listToAttrs (map (d: { name = d; value = { master = true; file = zonefile; }; }) (domains));
    };

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.resolvconf.useLocalResolver = true;
  };
}
