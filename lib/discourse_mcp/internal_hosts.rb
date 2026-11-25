# frozen_string_literal: true

module DiscourseMcp
  # The hosts that serve this site and its uploads: the site itself, its
  # configured base URL, and the CDN and upload store hosts. A URL on one of
  # them points at the site's own content.
  module InternalHosts
    module_function

    HOST_NAME = /\A[a-z0-9](?:[a-z0-9.\-]*[a-z0-9])?\z/
    NUMERIC_LABEL = /\A(?:0x[0-9a-f]*|[0-9]+)\z/
    DOTTED_QUAD =
      /\A(?:(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\z/

    # Browsers map many spellings onto one host (Unicode, IDNA mappings,
    # numeric shorthands for IP addresses), more than can be mirrored. So a
    # host counts as external only when it is written in a plain form: an
    # ASCII name, a dotted IPv4 address or an IPv6 literal. Any other spelling
    # counts as internal.
    #
    # @param uri [URI::Generic, Addressable::URI]
    # @returns [Boolean]
    def include?(uri)
      return false if uri.host.blank?

      host = plain(uri.host)
      host.nil? || hosts.include?(host)
    end

    # @returns [Set<String>]
    def hosts
      [
        Discourse.current_hostname,
        Discourse.base_url,
        GlobalSetting.cdn_url,
        SiteSetting.s3_cdn_url,
        (Discourse.store.absolute_base_url if Discourse.store.external?),
      ].compact_blank.filter_map { |value| configured(host_of(value)) }.to_set
    end

    # The host in its plain, comparable form, or nil when it is written any
    # other way.
    #
    # @param host [String]
    # @returns [String, nil]
    def plain(host)
      return ipv6(host) if host.start_with?("[")

      host = CGI.unescape(host).downcase.chomp(".")
      return if !host.match?(HOST_NAME)
      # Browsers read a host whose last label is numeric as an IPv4 address,
      # in decimal, octal or hexadecimal parts.
      return if host.split(".").last.match?(NUMERIC_LABEL) && !host.match?(DOTTED_QUAD)

      host
    end

    def ipv6(host)
      return if !host.end_with?("]")

      address = IPAddr.new(host[1..-2])
      return if !address.ipv6?
      # An IPv4-mapped address reaches the IPv4 host.
      address.ipv4_mapped? ? address.native.to_s : "[#{address}]"
    rescue IPAddr::Error
      nil
    end

    # Configured hosts may be written in Unicode.
    def configured(host)
      return if host.blank?
      return ipv6(host) if host.start_with?("[")

      Addressable::IDNA.to_ascii(host).downcase.chomp(".").presence
      # The IDNA backends raise different errors for malformed input.
    rescue StandardError
      host.downcase
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
