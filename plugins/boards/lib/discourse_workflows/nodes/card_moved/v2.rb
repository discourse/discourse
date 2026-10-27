# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module CardMoved
        class V2 < V1
          description(
            superclass.description.merge(
              version: "2.0",
              output_contracts: [{ schema: BoardsSchema::CARD_MOVED_V2_OUTPUT_SCHEMA }],
            ),
          )

          def output
            super.transform_keys(acting_user: :actor)
          end
        end
      end
    end
  end
end
