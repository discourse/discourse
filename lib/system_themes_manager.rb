# frozen_string_literal: true

class SystemThemesManager
  def self.sync!
    Theme::CORE_THEMES.keys.each { |theme_name| sync_theme!(theme_name) }
  end

  def self.sync_theme!(theme_name)
    theme_id = Theme::CORE_THEMES[theme_name]
    raise Discourse::InvalidParameters unless theme_id

    theme_dir = "#{Rails.root.join("themes/#{theme_name}")}"

    is_initial_install = !Theme.exists?(id: theme_id)

    before_save =
      if is_initial_install && theme_id == Theme::CORE_THEMES["horizon"]
        ->(t) { t.dark_color_scheme = t.color_schemes.find { |s| s.name == "Horizon Dark" } }
      end

    theme =
      RemoteTheme.import_theme_from_directory(
        theme_dir,
        theme_id: theme_id,
        allow_out_of_sequence_migration: !is_initial_install,
        before_save: before_save,
      )

    theme.update_column(:enabled, true) unless theme.enabled?

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
