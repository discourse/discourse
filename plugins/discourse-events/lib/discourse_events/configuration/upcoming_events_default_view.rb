# frozen_string_literal: true

require_dependency "enum_site_setting"

module DiscourseEvents
  module Configuration
    class UpcomingEventsDefaultView < EnumSiteSetting
      def self.valid_value?(val)
        values.any? { |v| v[:value].to_s == val.to_s }
      end

      def self.values
        @values ||= [
          { name: "discourse_events.toolbar_button.day", value: "day" },
          { name: "discourse_events.toolbar_button.week", value: "week" },
          { name: "discourse_events.toolbar_button.month", value: "month" },
          { name: "discourse_events.toolbar_button.year", value: "year" },
        ]
      end

      def self.translate_names?
        true
      end
    end
  end
end
