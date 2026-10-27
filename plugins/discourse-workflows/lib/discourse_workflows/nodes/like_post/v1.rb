# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module LikePost
      class V1 < NodeType
        include PostLiking

        LIKED = true

        description(PostLiking.description(name: "action:like_post", icon: "heart"))

        private

        def perform_change(post, actor)
          actor.guardian.ensure_can_see!(post)
          ::PostActionCreator.like(actor, post)
        end
      end
    end
  end
end
