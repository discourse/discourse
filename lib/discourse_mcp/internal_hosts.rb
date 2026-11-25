# frozen_string_literal: true

module DiscourseMcp
  # The hosts that serve this site and its uploads: the site itself, its
  # configured base URL, and the CDN and upload store hosts. A URL on one of
  # them points at the site's own content.
  module InternalHosts
    module_function

    # @param uri [URI::Generic]
    # @returns [Boolean]
    def include?(uri)
      uri.host.present? && hosts.include?(uri.host.downcase)
    end

    # @returns [Set<String>]
    def hosts
      [
        Discourse.current_hostname,
        Discourse.base_url,
        GlobalSetting.cdn_url,
        SiteSetting.s3_cdn_url,
        (Discourse.store.absolute_base_url if Discourse.store.external?),
      ].compact_blank.filter_map { |value| host_of(value) }.map(&:downcase).to_set
    end

    # Upload stores give protocol-relative base URLs, such as `//bucket.host`.
    def host_of(value)
      value = value.to_s
      return value if !value.include?("/")

      URI.parse(value.start_with?("//") ? "https:#{value}" : value).host
    rescue URI::Error
      nil
    end
  end
end
