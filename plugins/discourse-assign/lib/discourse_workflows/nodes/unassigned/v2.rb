# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Unassigned
        class V2 < V1
          description(
            superclass.description.merge(
              version: "2.0",
              output_contracts: [
                { schema: DiscourseAssign::Workflows::Schema::ASSIGNMENT_V2_OUTPUT_SCHEMA },
              ],
            ),
          )

          def output
            super.then do |data|
              data.merge(
                assignment: data[:assignment].transform_keys(assigned_by_user: :assigned_by),
              )
            end
          end
        end
      end
    end
  end
end
