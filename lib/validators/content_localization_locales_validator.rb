# frozen_string_literal: true

class ContentLocalizationLocalesValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == ""
    count = val.split("|").length
    SiteSetting.content_localization_max_locales >= count
  end

  def error_message
    I18n.t(
      "site_settings.errors.content_localization_locale_limit",
      max: SiteSetting.content_localization_max_locales,
    )
  end
end
