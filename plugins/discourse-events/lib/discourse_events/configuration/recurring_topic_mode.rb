# frozen_string_literal: true

require_dependency "enum_site_setting"

module DiscourseEvents
  module Configuration
    class RecurringTopicMode < EnumSiteSetting
      def self.valid_value?(val)
        values.any? { |v| v[:value].to_s == val.to_s }
      end

      def self.values
        @values ||= [
          { name: "discourse_events.recurring_topic_mode.reuse_topic", value: "reuse_topic" },
          {
            name: "discourse_events.recurring_topic_mode.create_next_topic",
            value: "create_next_topic",
          },
        ]
      end

      def self.translate_names?
        true
      end
    end
  end
end
