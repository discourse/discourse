# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module UnacceptSolution
        class V1 < DiscourseWorkflows::NodeType
          include SolutionAction

          NOT_ALLOWED_ERROR =
            "discourse_solved.discourse_workflows.solution_action.unaccept_not_allowed"

          description(
            SolutionAction.description(
              name: "action:unaccept_solution",
              icon: "far-square",
              changed: "False when the post wasn't an accepted solution",
            ),
          )

          private

          def change_post(exec_ctx, item_index)
            change_solution(
              ::DiscourseSolved::UnacceptAnswer,
              exec_ctx,
              item_index,
              allowed: :can_unaccept_answer,
            )
          end
        end
      end
    end
  end
end
