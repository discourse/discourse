module GlobalPath
  def path(p)
    "#{GlobalSetting.relative_url_root}#{p}"
  end
end
