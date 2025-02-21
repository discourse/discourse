# frozen_string_literal: true

class SiteSetting::Policy::SettingsAreUnshadowedGlobally < Service::PolicyBase
  delegate :options, to: :context
  delegate :params, to: :context

  def call
    @hidden_settings =
      params.settings.keys.select do |setting_name|
        SiteSetting.shadowed_settings.include?(setting_name)
      end
    @hidden_settings.empty?
  end

  def reason
    I18n.t(
      "errors.site_settings.site_settings_are_shadowed_globally",
      setting_names: @hidden_settings.join(", "),
    )
  end
end
