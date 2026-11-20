# frozen_string_literal: true

class LanguageSwitcherSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "none"
    SiteSetting.user_locale_selection_enabled? &&
      SiteSetting.content_localization_supported_locales.present?
  end

  def error_message
    I18n.t("site_settings.errors.content_localization_language_switcher_requirements")
  end
end
