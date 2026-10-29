# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicConvertedToPublicTopic
      class V1 < NodeType
        include TopicConversionTrigger

        description(
          TopicConversionTrigger.description(
            name: "trigger:topic_converted_to_public_topic",
            event: :topic_converted_to_public_topic,
            icon: "comment",
          ),
        )
      end
    end
  end
end
