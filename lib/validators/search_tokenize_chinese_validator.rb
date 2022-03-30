# frozen_string_literal: true

class SearchTokenizeChineseValidator
  def initialize(opts = {})
  end

  def valid_value?(value)
    !SiteSetting.search_tokenize_japanese
  end

  def error_message
    I18n.t("site_settings.errors.search_tokenize_japanese_enabled")
  end
end
