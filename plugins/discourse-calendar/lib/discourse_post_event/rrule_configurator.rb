# frozen_string_literal: true

class RRuleConfigurator
  def self.rule(recurrence:, starts_at:, recurrence_until: nil)
    rule =
      case recurrence
      when "every_day"
        "FREQ=DAILY"
      when "every_month"
        start_date = starts_at.beginning_of_month.to_date
        end_date = starts_at.end_of_month.to_date
        weekday = starts_at.strftime("%A")

        count = 0
        (start_date..end_date).each do |date|
          count += 1 if date.strftime("%A") == weekday
          break if date.day == starts_at.day
        end

        "FREQ=MONTHLY;BYDAY=#{count}#{weekday.upcase[0, 2]}"
      when "every_weekday"
        "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR"
      when "every_two_weeks"
        "FREQ=WEEKLY;INTERVAL=2;"
      when "every_four_weeks"
        "FREQ=WEEKLY;INTERVAL=4;"
      else
        byday = starts_at.strftime("%A").upcase[0, 2]
        "FREQ=WEEKLY;BYDAY=#{byday}"
      end

    rule += ";UNTIL=#{recurrence_until.strftime("%Y%m%dT%H%M%SZ")}" if recurrence_until
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
