# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      # Accept solution and Unaccept solution go through the services behind the solution button, with its
      # permissions. Each node defines NOT_ALLOWED_ERROR, the full key of its permission error.
      module SolutionAction
        include PostChangeAction

        def self.description(name:, icon:, changed:)
          PostChangeAction.description(
            name:,
            icon:,
            color: "green",
            i18n_scope: "solution_action",
            changed:,
          ).merge(
            available: -> { SiteSetting.solved_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_solved",
          )
        end

        private

        # The service checks the permission before the post's state, so reporting nothing changed still
        # needs it. Both services have a topic answer only when they accepted or unaccepted one.
        def change_solution(service, exec_ctx, item_index, allowed:, unchanged: nil)
          post_id = exec_ctx.get_node_parameter("post_id", item_index)
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)

          service.call(params: { post_id: }, guardian: actor.guardian) do
            on_success do |post:, topic_answer: nil|
              post_output(post, actor, changed: topic_answer.present?)
            end
            if unchanged
              on_failed_policy(unchanged) { |post:| post_output(post, actor, changed: false) }
            end
            on_failed_policy(allowed) do
              solution_error!(
                self.class::NOT_ALLOWED_ERROR,
                item_index,
                username: actor.username,
                post_id:,
              )
            end
            on_model_not_found(:post) do
              solution_error!(
                "discourse_solved.discourse_workflows.solution_action.post_not_found",
                item_index,
                post_id:,
              )
            end
            on_failure do
              solution_error!(
                "discourse_solved.discourse_workflows.solution_action.failed",
                item_index,
                post_id:,
              )
            end
          end
        end

        def solution_error!(key, item_index, **args)
          raise_node_error!(I18n.t(key, **args), item_index:)
        end
      end
    end
  end
end
