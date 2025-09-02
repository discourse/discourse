# frozen_string_literal: true

require_dependency "enum_site_setting"

class CalendarFirstDayOfWeek < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      { name: "user.notification_schedule.saturday", value: "saturday" },
      { name: "user.notification_schedule.sunday", value: "sunday" },
      { name: "user.notification_schedule.monday", value: "monday" },
    ]
  end

  def self.translate_names?
    true
  end
end
