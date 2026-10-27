# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLikeChanged
      class V2 < V1
        description(
          superclass.description.merge(
            version: "2.0",
            output_contracts: [{ schema: Schema.merge(OUTPUT_SCHEMA, Schema::POST_AUTHOR_SCHEMA) }],
          ),
        )

        private

        def subject_user
          @post.user
        end
      end
    end
  end
end
