# frozen_string_literal: true

class SiteSetting::Policy::SettingsAreVisible < Service::PolicyBase
  delegate :options, :params, to: :context

  def call
    @hidden_settings = params.settings.map(&:name).select(&method(:validate_setting))
    @hidden_settings.empty?
  end

  def reason
    I18n.t(
      "errors.site_settings.site_settings_are_hidden",
      setting_names: @hidden_settings.join(", "),
    )
  end

  private

  def validate_setting(setting_name)
    return false if options.allow_changing_hidden.include?(setting_name)
    SiteSetting.hidden_settings.include?(setting_name)
  end
end
