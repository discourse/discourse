module UrlHelper

  def is_local(url)
    Discourse.store.has_been_uploaded?(url) || url =~ /^\/assets\//
  end

  def absolute(url)
    url =~ /^\/[^\/]/ ? (Discourse.asset_host || Discourse.base_url_no_prefix) + url : url
  end

  def schemaless(url)
    url.gsub(/^https?:/, "")
  end

end
