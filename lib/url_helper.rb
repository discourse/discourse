class UrlHelper

  def self.is_local(url)
    url.present? && (
      Discourse.store.has_been_uploaded?(url) ||
      !!(url =~ /^\/(assets|plugins|images)\//) ||
      url.start_with?(Discourse.asset_host || Discourse.base_url_no_prefix)
    )
  end

  def self.absolute(url, cdn = Discourse.asset_host)
    cdn = "https:" << cdn if cdn && cdn =~ /^\/\//
    url =~ /^\/[^\/]/ ? (cdn || Discourse.base_url_no_prefix) + url : url
  end

  def self.absolute_without_cdn(url)
    self.absolute(url, nil)
  end

  def self.schemaless(url)
    url.sub(/^http:/i, "")
  end

  DOUBLE_ESCAPED_REGEXP ||= /%25([0-9a-f]{2})/i

  # Prevents double URL encode
  # https://stackoverflow.com/a/37599235
  def self.escape_uri(uri, pattern = URI::UNSAFE)
    encoded = URI.encode(uri, pattern)
    encoded.gsub!(DOUBLE_ESCAPED_REGEXP, '%\1')
    encoded
  end

end
