# frozen_string_literal: true

class SystemThemesManager
  def self.sync!
    Theme::CORE_THEMES.keys.each { |theme_name| sync_theme!(theme_name) }
  end

  def self.sync_theme!(theme_name)
    theme_id = Theme::CORE_THEMES[theme_name]
    raise Discourse::InvalidParameters unless theme_id

    theme_dir = "#{Rails.root}/themes/#{theme_name}"

    is_initial_install = !Theme.exists?(id: theme_id)

    remote_theme = RemoteTheme.import_theme_from_directory(theme_dir, theme_id: theme_id)
    remote_theme.update_column(:enabled, true)

    if is_initial_install
      if theme_id == Theme::CORE_THEMES["horizon"]
        remote_theme.update!(
          dark_color_scheme: remote_theme.color_schemes.find_by(name: "Horizon Dark"),
        )
      end
    end

    Stylesheet::Manager.clear_theme_cache!
  end

  # Don't want user history created from theme site setting changes
  # from system themes polluting specs.
  def self.clear_system_theme_user_history!
    return if !Rails.env.test?

    Theme::CORE_THEMES.each_key do |theme_name|
      UserHistory
        .where(action: UserHistory.actions[:change_theme_site_setting])
        .where("subject ILIKE :theme_name", theme_name: "#{theme_name}:%")
        .destroy_all
    end
  end
end
