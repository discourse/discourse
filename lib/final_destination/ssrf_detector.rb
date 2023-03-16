# frozen_string_literal: true

class FinalDestination
  module SSRFDetector
    class DisallowedIpError < SocketError
    end
    class LookupFailedError < SocketError
    end

    def self.standard_private_ranges
      @private_ranges ||= [
        IPAddr.new("0.0.0.0/8"),
        IPAddr.new("127.0.0.1"),
        IPAddr.new("172.16.0.0/12"),
        IPAddr.new("192.168.0.0/16"),
        IPAddr.new("10.0.0.0/8"),
        IPAddr.new("::1"),
        IPAddr.new("fc00::/7"),
        IPAddr.new("fe80::/10"),
      ]
    end

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

      if ip_in_ranges?(ip, blocked_ip_blocks) || ip_in_ranges?(ip, standard_private_ranges)
        return false
      end

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
