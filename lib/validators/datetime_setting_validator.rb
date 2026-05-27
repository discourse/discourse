# frozen_string_literal: true

class DatetimeSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    # DateTime.iso8601 checks the format but does not enforce timezone presence
    # so we need to do an additional check for the presence of timezone info.
    DateTime.iso8601(val)
    val.include?("T") && (val.end_with?("Z") || val.match?(/[+-]\d{2}:\d{2}$/))
  rescue ArgumentError, TypeError
    false
  end

  def error_message
    I18n.t("site_settings.errors.invalid_datetime")
  end
end
