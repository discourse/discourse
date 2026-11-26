# frozen_string_literal: true

class ThemeSettingUpdater
  def self.update(guardian, theme, name, value)
    guardian.ensure_can_edit_theme!(theme)
    previous_value = theme.cached_settings[name.to_sym]
    Theme.transaction do
      theme.update_setting(name.to_sym, value)
      theme.save!
      StaffActionLogger.new(guardian.user).log_theme_setting_change(
        name.to_sym,
        previous_value,
        value,
        theme,
      )
    end
  end
end
