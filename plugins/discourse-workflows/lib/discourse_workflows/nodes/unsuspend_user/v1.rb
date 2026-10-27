# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UnsuspendUser
      class V1 < NodeType
        include UserModerationAction

        NOT_ALLOWED_ERROR =
          "discourse_workflows.errors.user_moderation_action.unsuspend_not_allowed"

        description(
          UserModerationAction.description(
            name: "action:unsuspend_user",
            icon: "user-check",
            changed:
              "False when the user wasn't suspended, unless a suspension that ended hasn't been reported yet",
          ),
        )

        private

        # Like the admin unsuspend button: an ended suspension that hasn't been announced yet is ended now.
        def change_user(exec_ctx, item_index)
          actor, user = find_actor_and_user(exec_ctx, item_index)
          ensure_allowed!(actor.guardian.can_unsuspend?(user), actor, user, item_index)

          changed = ::UserSuspender.unsuspend(user, by_user: actor)

          user_output(user.reload, actor, changed:)
        end
      end
    end
  end
end
