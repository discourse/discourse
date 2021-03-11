# frozen_string_literal: true

# Sam: This has now forked of rails. Trouble is we would never like to use "about 1 month" ever, we only want months for 2 or more months.
#
# Backporting a fix to rails itself may get too complex
module FreedomPatches
  module Rails4

    def self.distance_of_time_in_words(from_time, to_time = 0, include_seconds = false, options = {})
      options = {
        scope: :'datetime.distance_in_words',
      }.merge!(options)

      from_time = from_time.to_time if from_time.respond_to?(:to_time)
      to_time = to_time.to_time if to_time.respond_to?(:to_time)
      distance = (to_time.to_f - from_time.to_f).abs
      distance_in_minutes = (distance / 60.0).round
      distance_in_seconds = distance.round

      I18n.with_options locale: options[:locale], scope: options[:scope] do |locale|
        case distance_in_minutes
        when 0..1
          return distance_in_minutes == 0 ?
                 locale.t(:less_than_x_minutes, count: 1) :
                 locale.t(:x_minutes, count: distance_in_minutes) unless include_seconds

            case distance_in_seconds
            when 0..4   then locale.t :less_than_x_seconds, count: 5
            when 5..9   then locale.t :less_than_x_seconds, count: 10
            when 10..19 then locale.t :less_than_x_seconds, count: 20
            when 20..39 then locale.t :half_a_minute
            when 40..59 then locale.t :less_than_x_minutes, count: 1
              else             locale.t :x_minutes,           count: 1
            end

        when 2..44           then locale.t :x_minutes,      count: distance_in_minutes
        when 45..89          then locale.t :about_x_hours,  count: 1
        when 90..1439        then locale.t :about_x_hours,  count: (distance_in_minutes.to_f / 60.0).round
        when 1440..2519      then locale.t :x_days,         count: 1

          # this is were we diverge from Rails
        when 2520..129599     then locale.t :x_days,         count: (distance_in_minutes.to_f / 1440.0).round
        when 129600..525599   then locale.t :x_months,       count: (distance_in_minutes.to_f / 43200.0).round
          else
          fyear = from_time.year
            fyear += 1 if from_time.month >= 3
            tyear = to_time.year
            tyear -= 1 if to_time.month < 3
            leap_years = (fyear > tyear) ? 0 : (fyear..tyear).count { |x| Date.leap?(x) }
            minute_offset_for_leap_year = leap_years * 1440
            # Discount the leap year days when calculating year distance.
            # e.g. if there are 20 leap year days between 2 dates having the same day
            # and month then the based on 365 days calculation
            # the distance in years will come out to over 80 years when in written
            # english it would read better as about 80 years.
            minutes_with_offset         = distance_in_minutes - minute_offset_for_leap_year
            remainder                   = (minutes_with_offset % 525600)
            distance_in_years           = (minutes_with_offset / 525600)
            if remainder < 131400
              locale.t(:about_x_years,  count: distance_in_years)
            elsif remainder < 394200
              locale.t(:over_x_years,   count: distance_in_years)
            else
              locale.t(:almost_x_years, count: distance_in_years + 1)
            end
        end
      end
    end

    def self.time_ago_in_words(from_time, include_seconds = false, options = {})
      distance_of_time_in_words(from_time, Time.now, include_seconds, options)
    end
  end
end
