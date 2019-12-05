# frozen_string_literal: true

class UrlHelper

  # At the moment this handles invalid URLs that browser address bar accepts
  # where second # is not encoded
  #
  # Longer term we can add support of simpleidn and encode unicode domains
  def self.relaxed_parse(url)
    url, fragment = url.split("#", 2)
    uri = URI.parse(url)
    if uri
      fragment = URI.escape(fragment) if fragment&.include?('#')
      uri.fragment = fragment
      uri
    end
  rescue URI::Error
  end

  def self.is_local(url)
    url.present? && (
      Discourse.store.has_been_uploaded?(url) ||
      !!(url =~ Regexp.new("^#{Discourse.base_uri}/(assets|plugins|images)/")) ||
      url.start_with?(Discourse.asset_host || Discourse.base_url_no_prefix)
    )
  end

  def self.absolute(url, cdn = Discourse.asset_host)
    cdn = "https:#{cdn}" if cdn && cdn =~ /^\/\//
    url =~ /^\/[^\/]/ ? (cdn || Discourse.base_url_no_prefix) + url : url
  end

  def self.absolute_without_cdn(url)
    self.absolute(url, nil)
  end

  def self.schemaless(url)
    url.sub(/^http:/i, "")
  end

  def self.secure_proxy_without_cdn(url)
    url = url.sub(SiteSetting.Upload.absolute_base_url, "/secure-media-uploads")
    self.absolute(url, nil)
  end

  DOUBLE_ESCAPED_REGEXP ||= /%25([0-9a-f]{2})/i

  # Prevents double URL encode
  # https://stackoverflow.com/a/37599235
  def self.escape_uri(uri, pattern = URI::UNSAFE)
    encoded = URI.encode(uri, pattern)
    encoded.gsub!(DOUBLE_ESCAPED_REGEXP, '%\1')
    encoded
  end

  def self.cook_url(url, secure: false)
    return url unless is_local(url)

    uri = URI.parse(url)
    filename = File.basename(uri.path)
    is_attachment = !FileHelper.is_supported_media?(filename)

    no_cdn = SiteSetting.login_required || SiteSetting.prevent_anons_from_downloading_files

    url = secure ? secure_proxy_without_cdn(url) : absolute_without_cdn(url)

    # we always want secure media to come from
    # Discourse.base_url_no_prefix/secure-media-uploads
    # to avoid asset_host mixups
    return schemaless(url) if secure

    unless is_attachment && no_cdn
      url = Discourse.store.cdn_url(url)
      url = local_cdn_url(url) if Discourse.store.external?
    end

    schemaless(url)
  rescue URI::Error
    url
  end

  def self.local_cdn_url(url)
    return url if Discourse.asset_host.blank?
    if url.start_with?("/#{Discourse.store.upload_path}/")
      "#{Discourse.asset_host}#{url}"
    else
      url.sub(Discourse.base_url_no_prefix, Discourse.asset_host)
    end
  end

end
