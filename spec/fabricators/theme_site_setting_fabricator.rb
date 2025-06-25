# frozen_string_literal: true

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
