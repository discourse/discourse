# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UnsilenceUser
      class V1 < NodeType
        include UserModerationAction

        NOT_ALLOWED_ERROR =
          "discourse_workflows.errors.user_moderation_action.unsilence_not_allowed"

        description(
          UserModerationAction.description(
            name: "action:unsilence_user",
            icon: "microphone",
            changed:
              "False when the user wasn't silenced, unless a silence that ended hasn't been lifted yet",
          ),
        )

        private

        # Like the admin unsilence button: a silence past its end that hasn't been lifted yet is lifted now.
        def change_user(exec_ctx, item_index)
          actor, user = find_actor_and_user(exec_ctx, item_index)
          ensure_allowed!(actor.guardian.can_unsilence_user?(user), actor, user, item_index)

          changed = ::UserSilencer.unsilence(user, actor)

          user_output(user.reload, actor, changed:)
        end
      end
    end
  end
end
