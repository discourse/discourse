# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Like and unlike post go through the like button's creator and destroyer, so they follow its rules. Each
    # node defines LIKED, whether the actor likes the post afterwards, and #perform_change.
    module PostLiking
      include PostChangeAction

      I18N_SCOPE = "post_liking"

      def self.description(name:, icon:)
        PostChangeAction.description(
          name:,
          icon:,
          color: "red",
          i18n_scope: I18N_SCOPE,
          changed: "False when the actor had already liked, or not liked, the post",
        )
      end

      private

      def change_post(exec_ctx, item_index)
        post = ::Post.find(exec_ctx.get_node_parameter("post_id", item_index))
        actor = exec_ctx.actor_from_parameter("actor_username", item_index)
        changed = false

        if liked?(post, actor) == self.class::LIKED
          actor.guardian.ensure_can_see!(post)
        else
          result = perform_change(post, actor)
          # A concurrent request by the same actor can make the change first: it then reports it, not this one.
          changed = result.success? && !result.try(:already_existed)
          if !changed && liked?(post, actor) != self.class::LIKED
            raise_node_error!(
              result.errors.full_messages.join(", ").presence ||
                I18n.t("discourse_workflows.errors.post_liking.failed", post_id: post.id),
              item_index:,
            )
          end
        end

        post.reload
        post_output(post, actor, changed:)
      end

      def liked?(post, actor)
        ::PostAction.exists?(
          post:,
          user: actor,
          post_action_type_id: ::PostActionType::LIKE_POST_ACTION_ID,
        )
      end
    end
  end
end
