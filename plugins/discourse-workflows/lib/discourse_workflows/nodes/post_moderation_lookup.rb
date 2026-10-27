# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Finds a post the way the post menu does (PostsController#find_post_using), which lets staff act on deleted
    # posts and on posts in deleted topics.
    module PostModerationLookup
      private

      def find_post(post_id, guardian)
        post = ::Post.with_deleted.find(post_id)
        if !(post.topic ||= ::Topic.with_deleted.find_by(id: post.topic_id))
          raise Discourse::NotFound
        end

        if (post.trashed? || post.topic.trashed?) && !guardian.can_moderate_topic?(post.topic)
          raise Discourse::InvalidAccess
        end
        guardian.ensure_can_see!(post)

        post
      end
    end
  end
end
