# frozen_string_literal: true

class SiteSetting::Policy::SettingsAreConfigurable < Service::PolicyBase
  delegate :options, :params, to: :context

  def call
    @unconfigurable_settings = params.settings.map(&:name).select(&method(:validate_setting))
    @unconfigurable_settings.empty?
  end

  def reason
    I18n.t(
      "errors.site_settings.site_settings_are_unconfigurable",
      setting_names: @unconfigurable_settings.join(", "),
    )
  end

  private

  def validate_setting(setting_name)
    SiteSetting.plugins[setting_name] &&
      !Discourse.plugins_by_name[SiteSetting.plugins[setting_name]].configurable?
  end
end
