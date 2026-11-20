# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicClosed
      class V1 < TopicStatusChanged::V1
        description(
          TopicStatusChanged::V1.description_for_change("closed").merge(
            defaults: {
              icon: "lock",
              color: "grey",
            },
            output_contracts: [
              { schema: Schema.merge(Schema::TOPIC_LIST_ITEM_SCHEMA, Schema::ACTOR_SCHEMA) },
            ],
          ),
        )

        def output
          { topic: serialize_topic_list_item(@topic), actor: serialize_user(@actor) }
        end
      end
    end
  end
end
