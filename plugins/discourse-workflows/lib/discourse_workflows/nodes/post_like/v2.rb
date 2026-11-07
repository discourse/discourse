# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLike
      class V2 < V1
        description(
          superclass.description.merge(
            version: "2.0",
            output_contracts: [
              { schema: Schema.document(OUTPUT_SCHEMA["properties"].except("username")) },
            ],
          ),
        )

        private

        def serialize_result(*)
          super.except(:username)
        end
      end
    end
  end
end
