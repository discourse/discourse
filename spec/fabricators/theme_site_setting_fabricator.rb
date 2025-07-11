# frozen_string_literal: true

# NOTE: For most cases, :theme_site_setting_with_service is the better choice to use,
# since it updates SiteSetting and other things properly.
Fabricator(:theme_site_setting) do
  theme { Theme.find_default }

  # NOTE: Only site settings with `themeable: true` are valid here.
  name { "enable_welcome_banner" }
  value { false }

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

Fabricator(:theme_site_setting_with_service, class_name: "Themes::ThemeSiteSettingManager") do
  # NOTE: Only site settings with `themeable: true` are valid here.
  transient :theme, :name, :value

  initialize_with do |transients|
    theme = transients[:theme] || Theme.find_default
    result =
      resolved_class.call(
        params: {
          theme_id: theme.id,
          name: transients[:name],
          value: transients[:value],
        },
        guardian: Discourse.system_user.guardian,
      )

    if result.failure?
      raise RSpec::Expectations::ExpectationNotMetError.new(
              "Service `#{resolved_class}` failed, see below for step details:\n\n" +
                result.inspect_steps,
            )
    end

    result.theme_site_setting
  end
end
