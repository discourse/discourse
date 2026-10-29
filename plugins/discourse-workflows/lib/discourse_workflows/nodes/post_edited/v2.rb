# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostEdited
      class V2 < V1
        description(
          superclass.description.merge(
            version: "2.0",
            output_contracts: [{ schema: Schema.merge(BASE_OUTPUT_SCHEMA, Schema::ACTOR_SCHEMA) }],
          ),
        )

        private

        def serialize_editor
          { actor: serialize_user(@revisor&.editor) }
        end
      end
    end
  end
end
