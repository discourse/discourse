# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Schedule
      module Payload
        module_function

        def build(time: Time.current, timezone:)
          local_time = time.in_time_zone(timezone)
          hour = local_time.hour % 12
          hour = 12 if hour.zero?
          readable_time = "#{hour}:#{local_time.strftime("%M:%S %P")}"

          {
            "timestamp" => local_time.iso8601(3),
            "readable_date" =>
              "#{local_time.strftime("%B")} #{local_time.day.ordinalize} #{local_time.year}, #{readable_time}",
            "readable_time" => readable_time,
            "day_of_week" => local_time.strftime("%A"),
            "year" => local_time.strftime("%Y"),
            "month" => local_time.strftime("%B"),
            "day_of_month" => local_time.strftime("%d"),
            "hour" => local_time.strftime("%H"),
            "minute" => local_time.strftime("%M"),
            "second" => local_time.strftime("%S"),
            "timezone" => "#{timezone} (UTC#{local_time.formatted_offset})",
          }
        end
      end
    end
  end
end
