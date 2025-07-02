# frozen_string_literal: true

class SystemThemesManager
  def self.sync!
    Theme::CORE_THEMES.keys.each { |theme_name| sync_theme!(theme_name) }
  end

  def self.sync_theme!(theme_name)
    theme_id = Theme::CORE_THEMES[theme_name]
    raise Discourse::InvalidParameters unless theme_id

    theme_dir = "#{Rails.root}/themes/#{theme_name}"

    remote_theme = RemoteTheme.import_theme_from_directory(theme_dir, theme_id: theme_id)
    if remote_theme.color_scheme
      remote_theme.color_scheme.update!(user_selectable: true)
      remote_theme
        .color_schemes
        .where(name: "#{remote_theme.color_scheme.name} Dark")
        .first
        &.update!(user_selectable: true)
    end
    Stylesheet::Manager.clear_theme_cache!
  end
end
