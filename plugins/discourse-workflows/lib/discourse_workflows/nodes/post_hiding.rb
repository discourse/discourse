# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Hide and unhide post go through Post#hide! and #unhide!, for staff only, like taking action on a flag and
    # the unhide button. Each node defines HIDDEN, whether the post is hidden afterwards, and #perform_change.
    module PostHiding
      include PostChangeAction
      include PostModerationLookup

      I18N_SCOPE = "post_hiding"

      def self.description(name:, icon:, properties: {})
        PostChangeAction.description(
          name:,
          icon:,
          color: "orange",
          i18n_scope: I18N_SCOPE,
          changed: "False when the post was already hidden, or already visible",
          properties:,
        )
      end

      private

      def change_post(exec_ctx, item_index)
        actor = exec_ctx.actor_from_parameter("actor_username", item_index)
        post = find_post(exec_ctx.get_node_parameter("post_id", item_index), actor.guardian)

        if !actor.guardian.is_staff?
          hiding_error!("not_allowed", item_index, username: actor.username, post_id: post.id)
        end

        before = post.hidden?
        perform_change(exec_ctx, post, actor, item_index) if before != self.class::HIDDEN

        post_output(post, actor, changed: post.hidden? != before)
      end

      def hiding_error!(key, item_index, **args)
        raise_node_error!(
          I18n.t("discourse_workflows.errors.post_hiding.#{key}", **args),
          item_index:,
        )
      end
    end
  end
end
