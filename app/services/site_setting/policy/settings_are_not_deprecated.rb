# frozen_string_literal: true

class SiteSetting::Policy::SettingsAreNotDeprecated < Service::PolicyBase
  delegate :options, :params, to: :context

  def call
    params.settings.keys.each do |id|
      SiteSettings::DeprecatedSettings::SETTINGS.find do |old_name, new_name, override, _|
        if old_name.to_sym == id
          if override
            options.overridden_setting_names[old_name.to_sym] = new_name
            break
          else
            @old_name = old_name
            @new_name = new_name
            return false
          end
        end
      end
    end

    true
  end

  def reason
    I18n.t(
      "errors.site_settings.site_settings_are_deprecated",
      old_name: @old_name,
      new_name: @new_name,
    )
  end
end
