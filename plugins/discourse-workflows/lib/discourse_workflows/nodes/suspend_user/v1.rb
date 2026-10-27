# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SuspendUser
      class V1 < NodeType
        include UserModerationAction

        NOT_ALLOWED_ERROR = "discourse_workflows.errors.user_moderation_action.suspend_not_allowed"

        description(
          UserModerationAction.penalty_description(
            name: "action:suspend_user",
            icon: "ban",
            end_field: :suspended_till,
            changed: "False when the user was already suspended, keeping that suspension",
          ),
        )

        def self.validate_configuration(configuration, errors)
          validate_timezone_configuration(configuration, errors)
        end

        private

        # Through the admin suspend modal's service, without its other users and post actions.
        def change_user(exec_ctx, item_index)
          actor, user = find_actor_and_user(exec_ctx, item_index)
          ensure_allowed!(actor.guardian.can_suspend?(user), actor, user, item_index)

          suspended_till = penalty_end(exec_ctx, "suspended_till", item_index)
          params = penalty_params(exec_ctx, user, item_index)
          changed =
            !user.suspended? &&
              apply_penalty(
                ::User::Suspend,
                actor,
                user,
                params.merge(suspend_until: suspended_till),
                item_index,
                already: :not_suspended_already,
                allowed: :can_suspend_all_users,
              )

          user.reload
          user_output(user, actor, changed:, expires_at: user.suspended_till.iso8601)
        end
      end
    end
  end
end
