# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicSlowModeSet
      class V1 < NodeType
        include TopicSlowModeTrigger

        description(
          TopicSlowModeTrigger.description(
            name: "trigger:topic_slow_mode_set",
            event: :topic_slow_mode_set,
            icon: "hourglass-start",
            output: TopicSlowMode::OUTPUT,
          ),
        )

        def initialize(topic, ends_at, payload = {})
          super(topic, payload)
          @ends_at = ends_at
        end

        def output
          super.merge(
            slow_mode_seconds: @topic.slow_mode_seconds,
            slow_mode_enabled_until: @ends_at&.utc&.iso8601,
          )
        end
      end
    end
  end
end
