# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AddReaction
        class V1 < DiscourseWorkflows::NodeType
          include PostReacting

          IF_EXISTS_OPTIONS = %w[keep replace].freeze

          description(
            PostReacting.description(
              name: "action:add_reaction",
              icon: "far-face-smile",
              changed:
                "False when the actor already had this reaction, or another one kept by if_exists",
              properties: {
                if_exists: {
                  type: :options,
                  required: true,
                  options: IF_EXISTS_OPTIONS,
                  default: "keep",
                },
              },
            ),
          )

          private

          def change_post(exec_ctx, item_index)
            replace = exec_ctx.get_node_parameter("if_exists", item_index) == "replace"

            react(exec_ctx, item_index) do |previous_reaction, reaction|
              previous_reaction != reaction && (previous_reaction.nil? || replace)
            end
          end
        end
      end
    end
  end
end
