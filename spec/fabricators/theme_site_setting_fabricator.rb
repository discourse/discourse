# frozen_string_literal: true

Fabricator(:theme_site_setting) do
  theme
  # NOTE: Only site settings with `themeable: true` are valid here.
  name { "enable_welcome_banner" }
  value { false }
  data_type { SiteSetting.types[:bool] }

  before_create do |theme_site_setting|
    setting_db_value, setting_data_type =
      SiteSetting.type_supervisor.to_db_value(
        theme_site_setting.name.to_sym,
        theme_site_setting.value,
      )
    theme_site_setting.value = setting_db_value
    theme_site_setting.data_type = setting_data_type
  end
end
