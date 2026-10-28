# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module RemoveReaction
        class V1 < DiscourseWorkflows::NodeType
          include PostReacting

          description(
            PostReacting.description(
              name: "action:remove_reaction",
              icon: "far-face-meh",
              changed: "False when the actor didn't have this reaction",
            ),
          )

          private

          def change_post(exec_ctx, item_index)
            react(exec_ctx, item_index) do |previous_reaction, reaction|
              previous_reaction == reaction
            end
          end
        end
      end
    end
  end
end
