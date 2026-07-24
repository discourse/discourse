# frozen_string_literal: true

module WildcardUrlChecker
  HOST_WILDCARD_PATTERN = "[A-Za-z0-9.-]*"
  HOST_WILDCARD_VALUE_REGEXP = /\A[A-Za-z0-9.-]+\z/
  URL_COMPONENT_WILDCARD_PATTERN = ".*"

  def self.check_url(url, url_to_check)
    uri_to_check = parse_valid_url(url_to_check)
    return false if uri_to_check.blank?
    return true if url == "*"

    uri = parse_valid_url(url)
    return false if uri.blank?

    uri.scheme.casecmp?(uri_to_check.scheme) && uri.port == uri_to_check.port &&
      uri.userinfo.to_s.casecmp?(uri_to_check.userinfo.to_s) &&
      hosts_match?(uri.host, uri_to_check.host) &&
      wildcard_match?(path_query(uri), path_query(uri_to_check), URL_COMPONENT_WILDCARD_PATTERN) &&
      wildcard_match?(uri.fragment.to_s, uri_to_check.fragment.to_s, URL_COMPONENT_WILDCARD_PATTERN)
  end

  private

  def self.parse_valid_url(url)
    uri = URI.parse(url)
    return uri if uri&.scheme.present? && uri&.host.present?

    nil
  rescue URI::InvalidURIError
    nil
  end

  def self.hosts_match?(host, host_to_check)
    host = host.downcase
    host_to_check = host_to_check.downcase

    if host.start_with?("*.") && host.count("*") == 1
      suffix = host.delete_prefix("*.")
      return(
        host_to_check.end_with?(".#{suffix}") &&
          host_to_check.delete_suffix(".#{suffix}").match?(HOST_WILDCARD_VALUE_REGEXP)
      )
    end

    wildcard_match?(host, host_to_check, HOST_WILDCARD_PATTERN)
  end

  def self.path_query(uri)
    path_query = uri.path.to_s
    path_query += "?#{uri.query}" if uri.query.present?
    path_query
  end

  def self.wildcard_match?(pattern, value, wildcard_pattern)
    escaped_pattern = Regexp.escape(pattern).gsub("\\*", wildcard_pattern)
    Regexp.new("\\A#{escaped_pattern}\\z", "i").match?(value)
  end
end
