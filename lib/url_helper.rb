module UrlHelper

  def is_local(url)
    Discourse.store.has_been_uploaded?(url) ||
    url =~ /^\/assets\// ||
    url =~ /^\/plugins\// ||
    url.start_with?(Discourse.asset_host || Discourse.base_url_no_prefix)
  end

  def absolute(url, cdn = Discourse.asset_host)
    url =~ /^\/[^\/]/ ? (cdn || Discourse.base_url_no_prefix) + url : url
  end

  def absolute_without_cdn(url)
    absolute(url, nil)
  end

  def schemaless(url)
    url.gsub(/^https?:/, "")
  end

end
