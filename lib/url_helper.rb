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
      # Addressable::URI::CharacterClasses::UNRESERVED is used here because without it
      # the # in the fragment is not encoded
      fragment = Addressable::URI.encode_component(fragment, Addressable::URI::CharacterClasses::UNRESERVED) if fragment&.include?('#')
      uri.fragment = fragment
      uri
    end
  rescue URI::Error
  end

  def self.encode_and_parse(url)
    URI.parse(Addressable::URI.encode(url))
  end

  def self.encode(url)
    Addressable::URI.encode(url)
  end

  def self.unencode(url)
    Addressable::URI.unencode(url)
  end

  def self.encode_component(url_component)
    Addressable::URI.encode_component(url_component)
  end

  def self.is_local(url)
    url.present? && (
      Discourse.store.has_been_uploaded?(url) ||
      !!(url =~ Regexp.new("^#{Discourse.base_path}/(assets|plugins|images)/")) ||
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
    self.absolute(Upload.secure_media_url_from_upload_url(url), nil)
  end

  def self.escape_uri(uri)
    return uri if s3_presigned_url?(uri)
    Addressable::URI.normalized_encode(uri)
  end

  def self.rails_route_from_url(url)
    path = URI.parse(encode(url)).path
    Rails.application.routes.recognize_path(path)
  rescue Addressable::URI::InvalidURIError, URI::InvalidComponentError
    nil
  end

  def self.s3_presigned_url?(url)
    url[/x-amz-(algorithm|credential)/i].present?
  end

  def self.cook_url(url, secure: false, local: nil)
    is_secure = SiteSetting.secure_media && secure
    local = is_local(url) if local.nil?
    return url if !local

    url = is_secure ? secure_proxy_without_cdn(url) : absolute_without_cdn(url)

    # we always want secure media to come from
    # Discourse.base_url_no_prefix/secure-media-uploads
    # to avoid asset_host mixups
    return schemaless(url) if is_secure

    # PERF: avoid parsing url except for extreme conditions
    # this is a hot path used on home page
    filename = url
    if url.include?("?")
      uri = URI.parse(url)
      filename = File.basename(uri.path)
    end

    # this technically requires a filename, but will work with a URL as long as it end with the
    # extension and has no query params
    is_attachment = !FileHelper.is_supported_media?(filename)

    no_cdn = SiteSetting.login_required || SiteSetting.prevent_anons_from_downloading_files
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
