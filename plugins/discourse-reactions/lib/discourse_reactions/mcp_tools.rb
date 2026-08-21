# frozen_string_literal: true

module DiscourseReactions
  module McpTools
    class SetReaction
      def self.call(arguments:, principal:)
        post = Post.find_by(id: arguments.fetch("post_id"))
        if post.blank? || !principal.guardian.can_see?(post)
          raise DiscourseMcp::ToolError, "Post not found"
        end
        DiscourseReactions::ReactionManager.new(
          reaction_value: arguments.fetch("reaction"),
          user: principal.user,
          post: post,
        ).toggle!
        DiscourseMcp::ToolHelpers.text_and_structured(
          post_id: post.id,
          reaction: arguments.fetch("reaction"),
        )
      end
    end
  end
end
