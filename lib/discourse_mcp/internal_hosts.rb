# frozen_string_literal: true

module DiscourseMcp
  # The hosts that serve this site and its uploads: the site itself, its
  # configured base URL, and the CDN and upload store hosts. A URL on one of
  # them points at the site's own content.
  module InternalHosts
    module_function

    # @param uri [URI::Generic, Addressable::URI]
    # @returns [Boolean]
    def include?(uri)
      host = canonical(uri.host)
      host.present? && hosts.include?(host)
    end

    # @returns [Set<String>]
    def hosts
      [
        Discourse.current_hostname,
        Discourse.base_url,
        GlobalSetting.cdn_url,
        SiteSetting.s3_cdn_url,
        (Discourse.store.absolute_base_url if Discourse.store.external?),
      ].compact_blank.filter_map { |value| canonical(host_of(value)) }.to_set
    end

    # Browsers treat percent-encoded, Unicode, uppercase and trailing-dot
    # spellings of a host as the same host, so hosts are compared in one
    # spelling.
    #
    # @param host [String, nil]
    # @returns [String, nil]
    def canonical(host)
      return if host.blank?

      Addressable::IDNA.to_ascii(CGI.unescape(host.to_s)).downcase.chomp(".").presence
      # The IDNA backends raise different errors for malformed input.
    rescue StandardError
      host.to_s.downcase
    end

    # Upload stores give protocol-relative base URLs, such as `//bucket.host`.
    def host_of(value)
      value = value.to_s
      return value if !value.include?("/")

      Addressable::URI.parse(value.start_with?("//") ? "https:#{value}" : value).host
    rescue Addressable::URI::InvalidURIError
      nil
    end
  end
end
