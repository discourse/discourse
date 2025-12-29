# frozen_string_literal: true

class DatetimeSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?

    begin
      # Only accept ISO 8601 datetime strings with timezone
      # Must contain 'T' (date/time separator) and timezone indicator (Z or offset)
      has_time_separator = val.include?("T")
      has_timezone = val.end_with?("Z") || val.match?(/[+-]\d{2}:\d{2}$/)
      return false unless has_time_separator && has_timezone

      DateTime.iso8601(val)
      true
    rescue ArgumentError, TypeError
      false
    end
  end

  def error_message
    I18n.t("site_settings.errors.invalid_datetime")
  end
end
