# frozen_string_literal: true

class SearchTokenizeJapaneseValidator
  def initialize(opts = {})
  end

  def valid_value?(value)
    !SiteSetting.search_tokenize_chinese
  end

  def error_message
    I18n.t("site_settings.errors.search_tokenize_chinese_enabled")
  end
end
