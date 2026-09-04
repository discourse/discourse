# frozen_string_literal: true

# Normalizes referrer URLs captured by browser pageview events so the same
# logical referrer groups consistently in the top-referrers report. It strips
# scheme, `www.`, port, fragment, trailing slashes, and common tracking query
# params, converts the host to lowercase punycode, and truncates the result to
# 2,000 bytes. It also normalizes pageview URLs to canonical site-relative
# paths for the Site Traffic Explorer.
class BrowserPageviewEventUrlNormalizer
  # Bump when referrer normalization changes significantly to re-backfill rows
  # stamped with an older version.
  REFERRER_VERSION = 1

  # Bump when site-path normalization changes significantly to re-backfill rows
  # stamped with an older version.
  SITE_PATH_VERSION = 1

  # TODO: consider vendoring DuckDuckGo's Tracker Radar tracking-parameter list
  # (https://github.com/duckduckgo/tracker-radar) for broader, maintained
  # coverage instead of this hand-curated subset.
  TRACKING_PARAMS = %w[
    utm_source
    utm_medium
    utm_campaign
    utm_term
    utm_content
    fbclid
    gclid
    mc_cid
    mc_eid
    ref_src
    _hsenc
    _hsmi
  ].to_set.freeze

  MAX_LENGTH = 2000

  class << self
    def normalize_referrer(raw)
      uri = parse_uri(raw)
      return nil if uri.nil?

      host = normalize_host(uri.host)
      return nil if host.blank?

      path = normalized_path(uri)
      filtered_query = filter_query(uri.query)
      query_str = filtered_query.empty? ? "" : "?#{filtered_query}"

      "#{host}#{path}#{query_str}".byteslice(0, MAX_LENGTH).scrub("")
    end

    def normalize_site_path(raw)
      uri = parse_uri(raw)
      return nil if uri.nil?
      return nil if uri.scheme.present? && (!%w[http https].include?(uri.scheme) || uri.host.blank?)

      path = normalized_path(uri)
      path = "/#{path}" if !path.start_with?("/")
      path = "/" if path.blank?
      path.byteslice(0, MAX_LENGTH).scrub("")
    end

    def normalize_host(host)
      return nil if host.blank?
      normalized = Addressable::URI.parse("http://#{host}").normalized_host
      return nil if normalized.blank?
      normalized.delete_prefix("www.").delete_suffix(".")
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def parse_uri(raw)
      return nil if raw.blank?

      Addressable::URI.parse(raw.to_s.strip)
    rescue Addressable::URI::InvalidURIError, ArgumentError, TypeError
      nil
    end

    private

    # Filters the raw query string so original percent-encoding is preserved
    # (avoids %20/+ duplicate groupings for rows pointing at the same URL).
    def filter_query(query)
      return "" if query.blank?

      query
        .split("&")
        .reject do |pair|
          key = pair.split("=", 2).first.to_s
          TRACKING_PARAMS.include?(key)
        end
        .join("&")
    end

    def normalized_path(uri)
      uri.path.to_s.sub(%r{/+\z}, "")
    end
  end

  private_class_method :parse_uri
end
