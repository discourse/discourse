# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostReactionChanged
        class V2 < V1
          V2_OUTPUT_SCHEMA =
            Schema.merge(OUTPUT_SCHEMA, Schema::POST_AUTHOR_SCHEMA, Schema::ACTOR_SCHEMA).freeze

          description(
            superclass.description.merge(
              version: "2.0",
              output_contracts: [{ schema: V2_OUTPUT_SCHEMA }],
            ),
          )

          def output
            super.then { |data| data.merge(user: serialize_user(@post.user), actor: data[:user]) }
          end
        end
      end
    end
  end
end
