# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module RevokeBadge
      class V1 < NodeType
        include BadgeAction

        NOT_ALLOWED_ERROR = "discourse_workflows.errors.badge_action.revoke_not_allowed"

        description(
          BadgeAction.description(
            name: "action:revoke_badge",
            color: "grey",
            changed: "False when the user didn't have the badge (for that post, when one is set)",
          ),
        )

        def self.load_options_context(context)
          load_badge_options(context)
        end

        private

        # Like the admin badge page, disabled badges included: every grant of the badge (or only the one for
        # post_id) is revoked and logged, and a title matching the badge is cleared.
        def change_user(exec_ctx, item_index)
          actor, user, badge = find_actor_user_and_badge(exec_ctx, item_index)
          post_id = badge_post_id(exec_ctx, item_index)

          user_badges = ::UserBadge.where(user:, badge:)
          user_badges = user_badges.where(post_id:) if post_id
          changed = user_badges.to_a.map { |user_badge| revoke(user_badge, actor) }.any?

          badge_output(user.reload, badge, actor, changed:)
        end

        # A concurrent revoke of the same grant raises once it has removed it.
        def revoke(user_badge, actor)
          ::BadgeGranter.revoke(user_badge, revoked_by: actor)
          true
        rescue ActiveRecord::RecordNotFound
          false
        end
      end
    end
  end
end
