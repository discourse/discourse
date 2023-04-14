# frozen_string_literal: true

class MarkdownTypographerQuotationMarksValidator
  QUOTE_COUNT = 4

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    value.present? && value.split("|").size == QUOTE_COUNT
  end

  def error_message
    I18n.t("site_settings.errors.list_value_count", count: QUOTE_COUNT)
  end
end
