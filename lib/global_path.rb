module GlobalPath
  def path(p)
    "#{GlobalSetting.relative_url_root}#{p}"
  end

  def cdn_path(p)
    "#{GlobalSetting.cdn_url}#{path(p)}"
  end

  def upload_cdn_path(p)
    if SiteSetting.Upload.s3_cdn_url.present?
      p = p.sub(Discourse.store.absolute_base_url, SiteSetting.Upload.s3_cdn_url)
    end
    p =~ /^http/ ? p : cdn_path(p)
  end

  def cdn_relative_path(path)
    if (cdn_url = GlobalSetting.cdn_url).present?
      URI.parse(cdn_url).path + path
    else
      path
    end
  end

end
