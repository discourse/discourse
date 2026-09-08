# frozen_string_literal: true

require_dependency "enum_site_setting"

class RemindAssignsFrequencySiteSettings < EnumSiteSetting
  DAILY_MINUTES = 24 * 60 * 1
  WEEKLY_MINUTES = DAILY_MINUTES * 7
  MONTHLY_MINUTES = DAILY_MINUTES * 30
  QUARTERLY_MINUTES = DAILY_MINUTES * 90

  class << self
    def valid_value?(val)
      val.to_i.to_s == val.to_s && values.any? { |v| v[:value] == val.to_i }
    end

    def values
      @values ||= [
        { name: "discourse_assign.reminders_frequency.never", value: 0 },
        { name: "discourse_assign.reminders_frequency.daily", value: DAILY_MINUTES },
        { name: "discourse_assign.reminders_frequency.weekly", value: WEEKLY_MINUTES },
        { name: "discourse_assign.reminders_frequency.monthly", value: MONTHLY_MINUTES },
        { name: "discourse_assign.reminders_frequency.quarterly", value: QUARTERLY_MINUTES },
      ]
    end

    def translate_names?
      true
    end

    def frequency_for(minutes)
      value = values.detect { |v| v[:value] == minutes }

      raise Discourse.InvalidParameters(:task_reminders_frequency) if value.nil?

      I18n.t(value[:name])
    end
  end
end
