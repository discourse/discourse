# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicSlowModeCleared
      class V1 < NodeType
        include TopicSlowModeTrigger

        description(
          TopicSlowModeTrigger.description(
            name: "trigger:topic_slow_mode_cleared",
            event: :topic_slow_mode_cleared,
            icon: "hourglass-end",
          ),
        )
      end
    end
  end
end
