# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicConvertedToPersonalMessage
      class V1 < NodeType
        include TopicConversionTrigger

        # A personal message has no category to filter on.
        description(
          TopicConversionTrigger.description(
            name: "trigger:topic_converted_to_personal_message",
            event: :topic_converted_to_private_message,
            icon: "envelope",
            properties: NodeType::TAG_FILTER_PROPERTIES,
          ),
        )
      end
    end
  end
end
