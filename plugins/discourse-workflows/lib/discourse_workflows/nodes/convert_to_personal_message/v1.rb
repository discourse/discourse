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

        def convert(_exec_ctx, topic, actor, _item_index)
          topic.convert_to_private_message(actor)
        end
      end
    end
  end
end
