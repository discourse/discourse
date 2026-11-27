# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Lock and unlock post go through PostLocker, for staff only, like the post admin menu. Each node defines
    # LOCKED, whether the post is locked afterwards.
    module PostLockAction
      include PostChangeAction
      include PostModerationLookup

      I18N_SCOPE = "post_lock_action"

      def self.description(name:, icon:)
        PostChangeAction.description(
          name:,
          icon:,
          color: "light-blue",
          i18n_scope: I18N_SCOPE,
          changed: "False when the post was already locked, or already unlocked",
        )
      end

      private

      def change_post(exec_ctx, item_index)
        actor = exec_ctx.actor_from_parameter("actor_username", item_index)
        post = find_post(exec_ctx.get_node_parameter("post_id", item_index), actor.guardian)
        actor.guardian.ensure_can_lock_post!(post)

        before = post.locked?
        if before != self.class::LOCKED
          locker = ::PostLocker.new(post, actor)
          self.class::LOCKED ? locker.lock : locker.unlock
        end

        post_output(post, actor, changed: post.locked? != before)
      end
    end
  end
end
