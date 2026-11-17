# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UnlikePost
      class V1 < NodeType
        include PostLiking

        LIKED = false

        description(PostLiking.description(name: "action:unlike_post", icon: "far-heart"))

        private

        # Like the unlike button: only the actor's own like, within the undo window, and no visibility check.
        def perform_change(post, actor)
          ::PostActionDestroyer.destroy(actor, post, :like)
        end
      end
    end
  end
end
