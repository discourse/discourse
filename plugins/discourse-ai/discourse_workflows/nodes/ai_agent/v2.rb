# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AiAgent
        class V2 < V1
          DEFAULT_RUNNER = "={{ $current_user.username || 'system' }}"

          description(
            superclass.description.deep_merge(
              version: "2.0",
              properties: {
                runner_username: {
                  default: DEFAULT_RUNNER,
                },
              },
            ),
          )

          private

          # A node saved without a runner resolves the default the editor would have written.
          def runner(exec_ctx, item_index)
            default = exec_ctx.evaluate_expression(DEFAULT_RUNNER, item_index)
            exec_ctx.actor_from_parameter("runner_username", item_index, default:)
          end
        end
      end
    end
  end
end
