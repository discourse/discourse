# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    # Server-side counterpart of `isLivestreamUrl` in raw-event-helper.js: both
    # accept a host listed in `livestream_allowed_hosts` and any of its
    # subdomains. Keep the two in sync.
    module AllowedHosts
      def self.list
        SiteSetting.livestream_allowed_hosts.to_s.split("|").filter_map { |host| normalize(host) }
      end

      def self.allows_url?(url)
        uri = URI.parse(url.to_s)
        return false if !uri.is_a?(URI::HTTP) || uri.host.blank?

        host = uri.host.downcase
        list.any? { |allowed| host == allowed || host.end_with?(".#{allowed}") }
      rescue URI::InvalidURIError
        false
      end

      # Admins routinely paste a full URL into a host list, so keep only the host.
      def self.normalize(host)
        host.to_s.downcase.strip.sub(%r{\Ahttps?://}, "").split("/").first.presence
      end
    end
  end
end
