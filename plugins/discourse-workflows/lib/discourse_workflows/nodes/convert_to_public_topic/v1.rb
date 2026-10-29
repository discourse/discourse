# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ConvertToPublicTopic
      class V1 < NodeType
        include TopicConversion

        TO_PRIVATE_MESSAGE = false

        description(
          TopicConversion.description(
            name: "action:convert_to_public_topic",
            icon: "comment",
            properties: {
              category_id: {
                type: :integer,
                required: false,
                ui: {
                  control: :category,
                },
              },
            },
          ),
        )

        private

        def convert(exec_ctx, topic, actor, item_index)
          category_id = exec_ctx.get_node_parameter("category_id", item_index).presence
          # The converter falls back to another category when the id doesn't exist.
          category = ::Category.find(category_id) if category_id

          topic.convert_to_public_topic(actor, category_id: category&.id)
        end
      end
    end
  end
end
