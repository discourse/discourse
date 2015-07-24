class UrlHelper

  def self.is_local(url)
    url.present? && (
      Discourse.store.has_been_uploaded?(url) ||
      !!(url =~ /^\/assets\//) ||
      !!(url =~ /^\/plugins\//) ||
      url.start_with?(Discourse.asset_host || Discourse.base_url_no_prefix)
    )
  end

  def self.absolute(url, cdn = Discourse.asset_host)
    url =~ /^\/[^\/]/ ? (cdn || Discourse.base_url_no_prefix) + url : url
  end

  def self.absolute_without_cdn(url)
    self.absolute(url, nil)
  end

  def self.schemaless(url)
    url.sub(/^http:/, "")
  end

end
