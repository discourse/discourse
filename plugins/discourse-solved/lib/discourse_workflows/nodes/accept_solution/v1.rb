# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AcceptSolution
        class V1 < DiscourseWorkflows::NodeType
          include SolutionAction

          NOT_ALLOWED_ERROR =
            "discourse_solved.discourse_workflows.solution_action.accept_not_allowed"

          description(
            SolutionAction.description(
              name: "action:accept_solution",
              icon: "square-check",
              changed: "False when the post was already an accepted solution",
            ),
          )

          private

          # Like the solution button: the author and watchers are notified, and without multiple solutions the
          # previous one is replaced.
          def change_post(exec_ctx, item_index)
            change_solution(
              ::DiscourseSolved::AcceptAnswer,
              exec_ctx,
              item_index,
              allowed: :can_accept_answer,
              unchanged: :answer_is_acceptable,
            )
          end
        end
      end
    end
  end
end
