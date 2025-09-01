# frozen_string_literal: true

require_dependency "enum_site_setting"

# Enumerator for the `calendar_first_day_of_week` site setting.
# Uses translation keys for weekday names so the admin UI is localized.
class CalendarFirstDayOfWeek < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      # Use existing client-side weekday translations
      { name: "user.notification_schedule.saturday", value: "Saturday" },
      { name: "user.notification_schedule.sunday", value: "Sunday" },
      { name: "user.notification_schedule.monday", value: "Monday" },
    ]
  end

  def self.translate_names?
    true
  end
end
