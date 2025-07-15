# frozen_string_literal: true

class CalendarSettingsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == ""

    split = val.split(":")
    return false if split.count != 2

    hour = split.first
    return false if hour.length != 2
    return false if hour.to_i < 0 || hour.to_i >= 24

    minutes = split.second
    return false if minutes.length != 2
    return false if minutes.to_i < 0 || minutes.to_i >= 60
    true
  end

  def error_message
    I18n.t("site_settings.all_day_event_time_error")
  end
end
