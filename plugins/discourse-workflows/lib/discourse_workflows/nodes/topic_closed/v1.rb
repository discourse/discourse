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
            output_contracts: [{ schema: Schema::TOPIC_LIST_ITEM_SCHEMA }],
          ),
        )

        def output
          { topic: topic_data(@topic) }
        end
      end
    end
  end
end
