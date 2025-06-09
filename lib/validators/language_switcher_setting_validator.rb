# frozen_string_literal: true

class LanguageSwitcherSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f" || val == "false"
    SiteSetting.set_locale_from_cookie &&
      SiteSetting.experimental_content_localization_supported_locales.present?
  end

  def error_message
    I18n.t("site_settings.errors.experimental_anon_language_switcher_requirements")
  end
end
