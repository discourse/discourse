# frozen_string_literal: true

class FinalDestination
  module SSRFDetector
    class DisallowedIpError < SSRFError
    end

    class LookupFailedError < SSRFError
    end

    # This is a list of private IPv4 IP ranges that are not allowed to be globally reachable as given by
    # https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml.
    PRIVATE_IPV4_RANGES = [
      IPAddr.new("0.0.0.0/8"),
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("100.64.0.0/10"),
      IPAddr.new("127.0.0.0/8"),
      IPAddr.new("169.254.0.0/16"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.0.0.0/24"),
      IPAddr.new("192.0.0.0/29"),
      IPAddr.new("192.0.0.8/32"),
      IPAddr.new("192.0.0.170/32"),
      IPAddr.new("192.0.0.171/32"),
      IPAddr.new("192.0.2.0/24"),
      IPAddr.new("192.168.0.0/16"),
      IPAddr.new("192.175.48.0/24"),
      IPAddr.new("198.18.0.0/15"),
      IPAddr.new("198.51.100.0/24"),
      IPAddr.new("203.0.113.0/24"),
      IPAddr.new("240.0.0.0/4"),
      IPAddr.new("255.255.255.255/32"),
    ].freeze

    # This is a list of private IPv6 IP ranges that are not allowed to be globally reachable as given by
    # https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry.xhtml.
    #
    # ::ffff:0:0/96 is excluded from the list because it is used for IPv4-mapped IPv6 addresses which is something we want to allow.
    PRIVATE_IPV6_RANGES = [
      IPAddr.new("::1/128"),
      IPAddr.new("::/128"),
      IPAddr.new("64:ff9b:1::/48"),
      IPAddr.new("100::/64"),
      IPAddr.new("2001::/23"),
      IPAddr.new("2001:2::/48"),
      IPAddr.new("2001:db8::/32"),
      IPAddr.new("fc00::/7"),
      IPAddr.new("fe80::/10"),
    ].freeze

    PRIVATE_IP_RANGES = PRIVATE_IPV4_RANGES + PRIVATE_IPV6_RANGES

    def self.blocked_ip_blocks
      SiteSetting
        .blocked_ip_blocks
        .split(/[|\n]/)
        .filter_map do |r|
          IPAddr.new(r.strip)
        rescue IPAddr::InvalidAddressError
          nil
        end
    end

    def self.allowed_internal_hosts
      hosts =
        [
          SiteSetting.Upload.s3_cdn_url,
          GlobalSetting.try(:cdn_url),
          Discourse.base_url_no_prefix,
        ].filter_map do |url|
          URI.parse(url).hostname if url
        rescue URI::Error
          nil
        end

      hosts += SiteSetting.allowed_internal_hosts.split(/[|\n]/).filter_map { |h| h.strip.presence }

      hosts
    end

    def self.host_bypasses_checks?(hostname)
      allowed_internal_hosts.any? { |h| h.downcase == hostname.downcase }
    end

    def self.ip_allowed?(ip)
      ip = ip.is_a?(IPAddr) ? ip : IPAddr.new(ip)
      ip = ip.native

      return false if ip_in_ranges?(ip, blocked_ip_blocks) || ip_in_ranges?(ip, PRIVATE_IP_RANGES)

      true
    end

    def self.lookup_and_filter_ips(name, timeout: nil)
      begin
        ips = lookup_ips(name, timeout: timeout)
      rescue SocketError
        raise LookupFailedError, "FinalDestination: lookup failed"
      end

      return ips if host_bypasses_checks?(name)

      ips.filter! { |ip| FinalDestination::SSRFDetector.ip_allowed?(ip) }

      raise DisallowedIpError, "FinalDestination: all resolved IPs were disallowed" if ips.empty?

      ips
    end

    def self.allow_ip_lookups_in_test!
      @allow_ip_lookups_in_test = true
    end

    def self.disallow_ip_lookups_in_test!
      @allow_ip_lookups_in_test = false
    end

    private

    def self.ip_in_ranges?(ip, ranges)
      ranges.any? { |r| r === ip }
    end

    def self.lookup_ips(name, timeout: nil)
      if Rails.env.test? && !@allow_ip_lookups_in_test
        ["1.2.3.4"]
      else
        FinalDestination::Resolver.lookup(name, timeout: timeout)
      end
    end
  end
end
