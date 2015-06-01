module GlobalPath
  def path(p)
    "#{GlobalSetting.relative_url_root}#{p}"
  end

  def cdn_path(p)
    "#{GlobalSetting.cdn_url}#{path(p)}"
  end
end
