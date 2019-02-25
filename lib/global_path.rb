module GlobalPath
  def path(p)
    "#{GlobalSetting.relative_url_root}#{p}"
  end

  def cdn_path(p)
    GlobalSetting.cdn_url.blank? ? p : "#{GlobalSetting.cdn_url}#{path(p)}"
  end

  def upload_cdn_path(p)
    if SiteSetting.Upload.s3_cdn_url.present?
      p = Discourse.store.cdn_url(p)
    end

    (p =~ /^http/ || p =~ /^\/\//) ? p : cdn_path(p)
  end

  def cdn_relative_path(path)
    if (cdn_url = GlobalSetting.cdn_url).present?
      URI.parse(cdn_url).path + path
    else
      path
    end
  end

  def full_cdn_url(url)
    uri = URI.parse(UrlHelper.absolute(upload_cdn_path(url)))
    uri.scheme = SiteSetting.scheme if uri.scheme.blank?
    uri.to_s
  end

end
