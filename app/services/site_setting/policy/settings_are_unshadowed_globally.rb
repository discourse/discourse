# frozen_string_literal: true

class SiteSetting::Policy::SettingsAreUnshadowedGlobally < Service::PolicyBase
  delegate :options, :params, to: :context

  def call
    @hidden_settings = params.settings.map(&:name).select(&method(:validate_setting))
    @hidden_settings.empty?
  end

  def reason
    I18n.t(
      "errors.site_settings.site_settings_are_shadowed_globally",
      setting_names: @hidden_settings.join(", "),
    )
  end

  private

  def validate_setting(setting_name)
    SiteSetting.shadowed_settings.include?(setting_name)
  end
end
