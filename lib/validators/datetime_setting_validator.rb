# frozen_string_literal: true

class DatetimeSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    DateTime.iso8601(val)
    true
  rescue ArgumentError, TypeError
    false
  end

  def error_message
    I18n.t("site_settings.errors.invalid_datetime")
  end
end
