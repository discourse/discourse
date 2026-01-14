# frozen_string_literal: true

require "holidays"

module DiscourseCalendar
  class Holiday
    def self.find_holidays_for(
      region_code:,
      start_date: Date.current.beginning_of_year,
      end_date: Date.current.end_of_year,
      show_holiday_observed_on_dates: false
    )
      holidays =
        Holidays.between(
          start_date,
          end_date,
          [region_code],
          show_holiday_observed_on_dates ? :observed : [],
        )

      holidays.map do |holiday|
        holiday[:disabled] = DiscourseCalendar::DisabledHoliday.where(
          region_code: region_code,
        ).exists?(holiday_name: holiday[:name])
      end

      holidays
    end
  end
end
