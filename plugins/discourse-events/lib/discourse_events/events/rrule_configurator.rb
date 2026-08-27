# frozen_string_literal: true

module DiscourseEvents
  module Events
    class RRuleConfigurator
      def self.rule(recurrence:, starts_at:, recurrence_until: nil)
        rule =
          case recurrence
          when "every_day"
            "FREQ=DAILY"
          when "every_month"
            weekday = starts_at.strftime("%A")
            nth = ((starts_at.day - 1) / 7) + 1

            # Every month has at least four of each weekday, so the first four
            # positions are safe. A fifth only exists in some months, so anchor it
            # to -1 ("last") instead, otherwise the rule would skip months.
            byday_count = nth == 5 ? -1 : nth

            "FREQ=MONTHLY;BYDAY=#{byday_count}#{weekday.upcase[0, 2]}"
          when "every_weekday"
            "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR"
          when "every_two_weeks"
            "FREQ=WEEKLY;INTERVAL=2"
          when "every_four_weeks"
            "FREQ=WEEKLY;INTERVAL=4"
          else
            byday = starts_at.strftime("%A").upcase[0, 2]
            "FREQ=WEEKLY;BYDAY=#{byday}"
          end

        rule += ";UNTIL=#{recurrence_until.strftime("%Y%m%dT%H%M%S")}" if recurrence_until
        rule
      end

      def self.how_many_recurring_events(recurrence:, max_years: nil)
        return 1 if !max_years
        per_year =
          case recurrence
          when "every_month"
            12
          when "every_four_weeks"
            13
          when "every_two_weeks"
            26
          when "every_weekday"
            260
          when "every_week"
            52
          when "every_day"
            365
          end
        per_year * max_years
      end
    end
  end
end
