# frozen_string_literal: true

class CoreThemesManager
  CORE_THEMES = { "foundation" => -1, "horizon" => -2 }
  def self.sync!
    CORE_THEMES.keys.each { |theme_name| sync_theme!(theme_name) }
  end

  def self.sync_theme!(theme_name)
    theme_id = CORE_THEMES[theme_name]
    return unless theme_id

    theme_dir = "#{Rails.root}/themes/#{theme_name}"
    return if !Dir.exist?(theme_dir)
    RemoteTheme.import_theme_from_directory(theme_dir, theme_id: theme_id)
    Stylesheet::Manager.clear_theme_cache!
  end
end
