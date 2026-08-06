# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    # Server-side counterpart of `isLivestreamUrl` in raw-event-helper.js: both
    # accept a host listed in `livestream_allowed_hosts` and any of its
    # subdomains. Keep the two in sync.
    module AllowedHosts
      # Browsers drop these outright before parsing a URL, so a comparison that
      # keeps them resolves a different host than the one that gets loaded.
      IGNORED_CHARACTERS = /[\t\n\r]/

      def self.list
        SiteSetting.livestream_allowed_hosts.to_s.split("|").filter_map { |entry| normalize(entry) }
      end

      def self.allows_url?(url)
        host = canonical_host(url)
        return false if host.blank?

        list.any? { |allowed| host == allowed || host.end_with?(".#{allowed}") }
      end

      # Admins routinely paste a full URL into a host list, so keep only the host.
      def self.normalize(entry)
        entry = entry.to_s.strip
        return if entry.blank?

        entry = "https://#{entry}" if !entry.match?(%r{\Ahttps?://}i)
        canonical_host(entry, require_https: false)
      end

      # Resolves the host the browser would actually connect to. Matching the
      # raw string instead lets an authority that only looks like an allowed
      # host through: browsers treat a backslash as a separator, strip control
      # characters, decode percent-escapes and map Unicode to punycode, so
      # `https://allowed.example\@evil.example/` loads `allowed.example` while
      # `https://%65vil.example/` loads `evil.example`.
      def self.canonical_host(url, require_https: true)
        cleaned = url.to_s.gsub(IGNORED_CHARACTERS, "").strip.tr("\\", "/")
        uri = Addressable::URI.parse(cleaned)&.normalize
        return if uri.nil? || uri.host.blank?
        return if require_https && uri.scheme != "https"

        uri.host
      rescue Addressable::URI::InvalidURIError
        nil
      end
    end
  end
end
