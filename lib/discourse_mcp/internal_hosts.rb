# frozen_string_literal: true

module DiscourseMcp
  # The hosts that serve this site and its uploads: the site itself, its
  # configured base URL, and the CDN and upload store hosts. A URL on one of
  # them points at the site's own content.
  module InternalHosts
    module_function

    HOST_NAME = /\A[a-z0-9](?:[a-z0-9.\-]*[a-z0-9])?\z/
    FULL_STOPS = /[\u3002\uFF0E\uFF61]/

    # A host that isn't a plain name after canonicalization counts as internal,
    # because browsers map more spellings onto a host than can be mirrored.
    #
    # @param uri [URI::Generic, Addressable::URI]
    # @returns [Boolean]
    def include?(uri)
      return false if uri.host.blank?

      host = canonical(uri.host)
      host.blank? || !host.match?(HOST_NAME) || hosts.include?(host)
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

      host = CGI.unescape(host.to_s).gsub(FULL_STOPS, ".")
      host = host.gsub(/\p{Default_Ignorable_Code_Point}/, "").unicode_normalize(:nfkc)
      Addressable::IDNA.to_ascii(host).downcase.chomp(".").presence
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
