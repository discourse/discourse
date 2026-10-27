# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ConvertToPersonalMessage
      class V1 < NodeType
        include TopicConversion

        TO_PRIVATE_MESSAGE = true

        description(
          TopicConversion.description(name: "action:convert_to_personal_message", icon: "envelope"),
        )

        private

        def convert(_exec_ctx, topic, actor, item_index)
          # Converting drops the banner without removing it, so its events and live update never happen.
          if topic.archetype == ::Archetype.banner
            raise_node_error!(conversion_error("banner", topic), item_index:)
          end

          topic.convert_to_private_message(actor)
        end
      end
    end
  end
end
