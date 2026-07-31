# frozen_string_literal: true

class DateSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?

    Date.iso8601(val).iso8601 == val
  rescue ArgumentError, TypeError
    false
  end

  def error_message
    I18n.t("site_settings.errors.invalid_date")
  end
end
