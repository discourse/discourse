# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module GrantBadge
      class V1 < NodeType
        include BadgeAction

        NOT_ALLOWED_ERROR = "discourse_workflows.errors.badge_action.grant_not_allowed"

        description(
          BadgeAction.description(
            name: "action:grant_badge",
            color: "yellow",
            changed:
              "False when the user already had the badge (for that post, for a badge granted several times)",
          ),
        )

        def self.load_options_context(context)
          load_badge_options(context)
        end

        private

        # Like the admin badge page, system badges included: the user is notified and the grant logged.
        def change_user(exec_ctx, item_index)
          actor, user, badge = find_actor_user_and_badge(exec_ctx, item_index)
          if !badge.enabled?
            raise_node_error!(
              I18n.t("discourse_workflows.errors.badge_action.badge_disabled", badge: badge.name),
              item_index:,
            )
          end
          post_id = grant_post_id(exec_ctx, actor, item_index)

          previous_ids = ::UserBadge.where(user:, badge:).pluck(:id)
          user_badge = grant(badge, user, actor, post_id)
          if user_badge.nil? && !held?(user, badge, post_id)
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.badge_action.grant_failed",
                badge: badge.name,
                target: user.username,
              ),
              item_index:,
            )
          end

          changed = user_badge.present? && previous_ids.exclude?(user_badge.id)
          badge_output(user, badge, actor, changed:)
        end

        def grant_post_id(exec_ctx, actor, item_index)
          post_id = badge_post_id(exec_ctx, item_index)
          return if post_id.nil?

          post = ::Post.find_by(id: post_id)
          badge_post_not_found!(post_id, item_index) if !actor.guardian.can_see?(post)
          post.id
        end

        # A concurrent grant of the same badge wins the unique index, or the validation once it committed.
        def grant(badge, user, actor, post_id)
          ::BadgeGranter.grant(badge, user, granted_by: actor, post_id:)
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
          nil
        end

        def held?(user, badge, post_id)
          user_badges = ::UserBadge.where(user:, badge:)
          user_badges = user_badges.where(post_id:) if badge.multiple_grant? && post_id
          user_badges.exists?
        end
      end
    end
  end
end
