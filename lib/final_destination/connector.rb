# frozen_string_literal: true

class FinalDestination
  # FinalDestination resolves hostnames to allowed IPs, then encodes them in a
  # pipe-separated format to be read by our patched versions of TCPSocket and 
  # Addrinfo in `freedom_patches/final_destination_connect.rb`.
  # This module exists to encode/decode that format.
  module Connector
    TOKEN_SUFFIX = ".final-destination.invalid"

    class << self
      def encode(host, ips)
        "#{host}|#{ips.join(",")}#{TOKEN_SUFFIX}"
      end

      def token?(name)
        name.is_a?(String) && name.end_with?(TOKEN_SUFFIX)
      end

      def addresses(token)
        token.delete_suffix(TOKEN_SUFFIX).rpartition("|").last.split(",")
      end

      def addresses_for_family(ips, family)
        wanted =
          case family
          when Integer then family
          when :ipv6, "ipv6", :INET6, "INET6", "AF_INET6" then Socket::AF_INET6
          when :ipv4, "ipv4", :INET, "INET", "AF_INET" then Socket::AF_INET
          end
        return ips unless wanted
        ips.select { |ip| Addrinfo.ip(ip).afamily == wanted }
      end
    end
  end
end
