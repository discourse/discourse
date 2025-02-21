# frozen_string_literal: true

class SiteSetting::Policy::SettingsAreVisible < Service::PolicyBase
  delegate :options, to: :context
  delegate :params, to: :context

  def call
    @hidden_settings =
      params.settings.keys.select do |setting_name|
        next false if options.allow_changing_hidden.include?(setting_name)
        SiteSetting.hidden_settings.include?(setting_name)
      end
    @hidden_settings.empty?
  end

  def reason
    I18n.t(
      "errors.site_settings.site_settings_are_hidden",
      setting_names: @hidden_settings.join(", "),
    )
  end
end
