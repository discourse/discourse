# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Topic
      class V2 < V1
        TOPIC_RESULT_SCHEMA = Schema.merge(TOPIC_SCHEMA, Schema::TOPIC_AUTHOR_SCHEMA)

        description(
          superclass.description.merge(
            version: "2.0",
            output_contracts: output_contracts_for(TOPIC_RESULT_SCHEMA, Schema::POST_SCHEMA),
          ),
        )

        private

        def serialize_topic_result(topic, guardian, **)
          super.merge(user: serialize_user(topic.user, guardian:))
        end

        def serialize_topic_post(post, guardian)
          serialize_post(post, guardian:, include_cooked: true)
        end
      end
    end
  end
end
