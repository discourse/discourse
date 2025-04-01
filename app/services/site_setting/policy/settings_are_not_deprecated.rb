# frozen_string_literal: true

class SiteSetting::Policy::SettingsAreNotDeprecated < Service::PolicyBase
  delegate :options, :params, to: :context

  def call
    @hard_deprecations =
      params.settings.filter_map do |setting|
        SiteSettings::DeprecatedSettings::SETTINGS.find do |old_name, new_name, override, _|
          if old_name.to_sym == setting.name
            if override
              options.overridden_setting_names[old_name.to_sym] = new_name
              break
            else
              break old_name, new_name
            end
          end
        end
      end

    @hard_deprecations.empty?
  end

  def reason
    old_names, new_names = @hard_deprecations.transpose

    I18n.t(
      "errors.site_settings.site_settings_are_deprecated",
      old_names: old_names.join(", "),
      new_names: new_names.join(", "),
    )
  end
end
