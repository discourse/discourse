# frozen_string_literal: true

class ContentLocalizationCrawlerParamValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    SiteSetting.set_locale_from_param
  end

  def error_message
    I18n.t("site_settings.errors.content_localization_crawler_param_requirements")
  end
end
