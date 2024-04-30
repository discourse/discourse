# frozen_string_literal: true

class UrlHelper
  MAX_URL_LENGTH = 2_000

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
      fragment =
        Addressable::URI.encode_component(
          fragment,
          Addressable::URI::CharacterClasses::UNRESERVED,
        ) if fragment&.include?("#")
      uri.fragment = fragment
      uri
    end
  rescue URI::Error
  end

  # Heuristic checks to determine if the URL string is a valid absolute URL, path or anchor
  def self.is_valid_url?(url)
    uri = URI.parse(url)

    return true if uri.is_a?(URI::Generic) && url.starts_with?("/") || url.match?(/\A\#([^#]*)/)

    if uri.scheme
      return true if uri.is_a?(URI::MailTo)

      if url.match?(%r{\A#{uri.scheme}://[^/]}) &&
           (
             uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS) || uri.is_a?(URI::FTP) ||
               uri.is_a?(URI::LDAP)
           )
        return true
      end
    end

    false
  rescue URI::InvalidURIError
    false
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
    url.present? &&
      (
        Discourse.store.has_been_uploaded?(url) ||
          !!(url =~ Regexp.new("^#{Discourse.base_path}/(assets|plugins|images)/")) ||
          url.start_with?(Discourse.asset_host || Discourse.base_url_no_prefix)
      )
  end

  def self.absolute(url, cdn = Discourse.asset_host)
    cdn = "https:#{cdn}" if cdn && cdn =~ %r{\A//}
    url =~ %r{\A/[^/]} ? (cdn || Discourse.base_url_no_prefix) + url : url
  end

  def self.absolute_without_cdn(url)
    self.absolute(url, nil)
  end

  def self.schemaless(url)
    url.sub(/\Ahttp:/i, "")
  end

  def self.secure_proxy_without_cdn(url)
    self.absolute(Upload.secure_uploads_url_from_upload_url(url), nil)
  end

  def self.normalized_encode(uri)
    url = uri.to_s

    if url.length > MAX_URL_LENGTH
      raise ArgumentError.new("URL starting with #{url[0..100]} is too long")
    end

    # Ideally we will jump straight to `Addressable::URI.normalized_encode`. However,
    # that implementation has some edge-case issues like https://github.com/sporkmonger/addressable/issues/472.
    # To temporaily work around those issues for the majority of cases, we try parsing with `::URI`.
    # If that fails (e.g. due to non-ascii characters) then we will fall back to addressable.
    # Hopefully we can simplify this back to `Addressable::URI.normalized_encode` in the future.

    # edge case where we expect mailto:test%40test.com to normalize to mailto:test@test.com
    return normalize_with_addressable(url) if url.match(/\Amailto:/)

    # If it doesn't pass the regexp, it's definitely not gonna parse with URI.parse. Skip
    # to addressable
    return normalize_with_addressable(url) if !url.match?(/\A#{URI.regexp}\z/)

    begin
      normalize_with_ruby_uri(url)
    rescue URI::Error
      normalize_with_addressable(url)
    end
  end

  def self.rails_route_from_url(url)
    path = URI.parse(encode(url)).path
    Rails.application.routes.recognize_path(path)
  rescue Addressable::URI::InvalidURIError, URI::InvalidComponentError
    nil
  end

  def self.cook_url(url, secure: false, local: nil)
    is_secure = SiteSetting.secure_uploads && secure
    local = is_local(url) if local.nil?
    return url if !local

    url = is_secure ? secure_proxy_without_cdn(url) : absolute_without_cdn(url)

    # we always want secure uploads to come from
    # Discourse.base_url_no_prefix/secure-uploads
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

  private

  def self.normalize_with_addressable(url)
    u = Addressable::URI.normalized_encode(url, Addressable::URI)

    u.host = ::Addressable::IDNA.to_ascii(u.host) if u.host && !u.host.ascii_only?

    u.to_s
  end

  def self.normalize_with_ruby_uri(url)
    u = URI.parse(url)

    u.scheme = u.scheme.downcase if u.scheme && u.scheme != u.scheme.downcase

    u.host = u.host.downcase if u.host && u.host != u.host.downcase

    u.to_s
  end
end
