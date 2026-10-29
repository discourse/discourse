# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UnhidePost
      class V1 < NodeType
        include PostHiding

        HIDDEN = false

        description(PostHiding.description(name: "action:unhide_post", icon: "eye"))

        private

        def perform_change(_exec_ctx, post, actor, item_index)
          post.unhide!(acting_user: actor)
        rescue ActiveRecord::RecordInvalid
          hiding_error!(
            "unhide_failed",
            item_index,
            post_id: post.id,
            errors: post.errors.full_messages.join(", "),
          )
        end
      end
    end
  end
end
