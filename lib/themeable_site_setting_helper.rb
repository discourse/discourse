# frozen_string_literal: true

class ThemeableSiteSettingHelper
  attr_reader :theme_id

  def initialize(theme_id:)
    @theme_id = theme_id
  end

  # TODO (martin)
  #
  # What should the DB backing store here be? We are
  # storing site settings essentially...so maybe we
  # need a duplicate of the SiteSetting table?
  #
  # Need the following:
  #
  #   * name
  #   * data_type
  #   * value
  #   * theme_id
  #
  # Also need to take into account the theme about.json
  # overrides for the settings...
  #
  # Maybe need a new section in the about.json file like this:
  #
  # themeable_site_settings: {
  #   enable_welcome_banner: true
  # }
  #
  # The order needs to be something like:
  #
  # * Resolve db value for the theme
  # * If there is no db value, then use the about.json value for the theme
  # * If there is no db value or about.json value, then use the value from
  #   the site setting
  def resolved_themeable_site_settings
    themeable_site_settings =
      SiteSetting.all_settings.select { |setting| setting[:themeable] }.map { |s| s[:setting] }
    db_values = settings_from_store(themeable_site_setting_names)

    themeable_site_settings.each_with_object({}) do |setting, hash|
      db_value = db_values.find { |db_setting| db_setting.name == setting }
      if db_value.present?
        hash[setting] = db_value.value
      else
        # TODO (martin)
        #
        # Dont think we can do this at runtime, we have to do thid at
        # import time for themes the same way we do for screenshots :/
        #
        # Maybe we always need a ThemeSiteSetting entry, if the theme
        # is changing the default from the site setting?
        about_json_value = @theme.about_json["themeable_site_settings"]&.dig(setting)

        if about_json_value.present?
          hash[setting] = about_json_value
        else
          hash[setting] = SiteSetting.get(setting)
        end
      end
    end
  end

  def settings_from_store(themeable_site_setting_names)
    database_values =
      ThemeSiteSetting.where(theme_id: @theme_id, name: themeable_site_setting_names)
  end
end
