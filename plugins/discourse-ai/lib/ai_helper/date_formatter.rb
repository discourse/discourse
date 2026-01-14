# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class DateFormatter
      DAYS_OF_WEEK = {
        "monday" => 1,
        "tuesday" => 2,
        "wednesday" => 3,
        "thursday" => 4,
        "friday" => 5,
        "saturday" => 6,
        "sunday" => 0,
      }

      class << self
        def process_date_placeholders(text, user)
          return text if !text.include?("{{")

          timezone = user.user_option.timezone || "UTC"
          reference_time = Time.now.in_time_zone(timezone)

          text.gsub(
            /\{\{(date_time_offset_minutes|date_offset_days|datetime|date|next_week):([^}]+)\}\}/,
          ) do |match|
            type = $1
            value = $2

            case type
            when "datetime"
              if value.include?(":")
                # Handle range like "2pm+1:3pm+2"
                start_str, end_str = value.split(":")
                format_datetime_range(
                  parse_time_with_offset(start_str, reference_time),
                  parse_time_with_offset(end_str, reference_time),
                  timezone,
                )
              else
                # Handle single time like "2pm+1" or "10pm"
                format_date_time(parse_time_with_offset(value, reference_time), timezone)
              end
            when "next_week"
              if value.include?(":")
                # Handle range like "tuesday-1pm:tuesday-3pm"
                start_str, end_str = value.split(":")
                start_time = parse_next_week(start_str, reference_time)
                end_time = parse_next_week(end_str, reference_time)
                format_datetime_range(start_time, end_time, timezone)
              else
                # Handle single time like "tuesday-1pm" or just "tuesday"
                time = parse_next_week(value, reference_time)
                value.include?("-") ? format_date_time(time, timezone) : format_date(time, timezone)
              end
            when "date"
              format_date(reference_time + value.to_i.days, timezone)
            when "date_time_offset_minutes"
              if value.include?(":")
                start_offset, end_offset = value.split(":").map(&:to_i)
                format_datetime_range(
                  reference_time + start_offset.minutes,
                  reference_time + end_offset.minutes,
                  timezone,
                )
              else
                format_date_time(reference_time + value.to_i.minutes, timezone)
              end
            when "date_offset_days"
              if value.include?(":")
                start_offset, end_offset = value.split(":").map(&:to_i)
                format_date_range(
                  reference_time + start_offset.days,
                  reference_time + end_offset.days,
                  timezone,
                )
              else
                format_date(reference_time + value.to_i.days, timezone)
              end
            end
          end
        end

        private

        def parse_next_week(str, reference_time)
          if str.include?("-")
            # Handle day with time like "tuesday-1pm"
            day, time = str.split("-")
            target_date = get_next_week_day(day.downcase, reference_time)
            parse_time(time, target_date)
          else
            # Just the day
            get_next_week_day(str.downcase, reference_time)
          end
        end

        def get_next_week_day(day, reference_time)
          raise ArgumentError unless DAYS_OF_WEEK.key?(day)

          target_date = reference_time + 1.week
          days_ahead = DAYS_OF_WEEK[day] - target_date.wday
          days_ahead += 7 if days_ahead < 0
          target_date + days_ahead.days
        end

        def parse_time_with_offset(time_str, reference_time)
          if time_str.include?("+")
            time_part, days = time_str.split("+")
            parse_time(time_part, reference_time + days.to_i.days)
          else
            parse_time(time_str, reference_time)
          end
        end

        def parse_time(time_str, reference_time)
          hour = time_str.to_i
          if time_str.downcase.include?("pm") && hour != 12
            hour += 12
          elsif time_str.downcase.include?("am") && hour == 12
            hour = 0
          end

          reference_time.change(hour: hour, min: 0, sec: 0)
        end

        def format_date(time, timezone)
          "[date=#{time.strftime("%Y-%m-%d")} timezone=\"#{timezone}\"]"
        end

        def format_date_time(time, timezone)
          "[date=#{time.strftime("%Y-%m-%d")} time=#{time.strftime("%H:%M:%S")} timezone=\"#{timezone}\"]"
        end

        def format_date_range(start_time, end_time, timezone)
          "[date-range from=#{start_time.strftime("%Y-%m-%d")} to=#{end_time.strftime("%Y-%m-%d")} timezone=\"#{timezone}\"]"
        end

        def format_datetime_range(start_time, end_time, timezone)
          "[date-range from=#{start_time.strftime("%Y-%m-%dT%H:%M:%S")} to=#{end_time.strftime("%Y-%m-%dT%H:%M:%S")} timezone=\"#{timezone}\"]"
        end
      end
    end
  end
end
