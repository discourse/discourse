# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ClearSlowMode
      class V1 < NodeType
        include TopicSlowMode

        description(
          TopicSlowMode.description(name: "action:clear_slow_mode", icon: "hourglass-end"),
        )

        private

        def change(exec_ctx, topic, actor, item_index)
          seconds_before = topic.slow_mode_seconds
          update_slow_mode(topic, actor, item_index, seconds: 0)

          {
            topic: serialize_topic(topic, guardian: actor.guardian),
            changed: topic.slow_mode_seconds != seconds_before,
          }
        end
      end
    end
  end
end
