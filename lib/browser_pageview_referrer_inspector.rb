# frozen_string_literal: true

# Normalizes referrer URLs captured by the browser pageview middleware so the
# same logical referrer groups consistently in the top-referrers report. It
# strips scheme, `www.`, port, fragment, trailing slashes, and common tracking
# query params, converts the host to lowercase punycode, and truncates the
# result to 200 bytes.
class BrowserPageviewReferrerInspector
  # Bump when the normalization logic changes significantly to trigger a
  # re-backfill of rows stamped with an older version.
  VERSION = 1

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

  def self.normalize(raw)
    return nil if raw.blank?

    # Scheme is intentionally dropped: `http://example.com/x` and
    # `https://example.com/x` collapse to the same key so the report groups
    # cross-protocol traffic together.
    uri = Addressable::URI.parse(raw.to_s.strip)
    return nil if uri.nil?

    host = normalize_host(uri.host)
    return nil if host.blank?

    path = uri.path.to_s.sub(%r{/+\z}, "")
    filtered_query = filter_query(uri.query)
    query_str = filtered_query.empty? ? "" : "?#{filtered_query}"

    "#{host}#{path}#{query_str}".byteslice(0, MAX_LENGTH).scrub("")
  rescue Addressable::URI::InvalidURIError, ArgumentError, TypeError
    nil
  end

  def self.normalize_host(host)
    return nil if host.blank?
    normalized = Addressable::URI.parse("http://#{host}").normalized_host
    return nil if normalized.blank?
    normalized.delete_prefix("www.").delete_suffix(".")
  rescue Addressable::URI::InvalidURIError
    nil
  end

  # Filters the raw query string so original percent-encoding is preserved
  # (avoids %20/+ duplicate groupings for rows pointing at the same URL).
  def self.filter_query(query)
    return "" if query.blank?

    query
      .split("&")
      .reject do |pair|
        key = pair.split("=", 2).first.to_s
        TRACKING_PARAMS.include?(key)
      end
      .join("&")
  end
  private_class_method :filter_query
end
