# frozen_string_literal: true

module DiscourseReactions
  module McpTools
    class SetReaction
      def self.call(arguments:, request_context:)
        post = Post.find_by(id: arguments.fetch("post_id"))
        if post.blank? || !request_context.guardian.can_see?(post)
          raise DiscourseMcp::ToolError, "Post not found"
        end
        reaction = arguments.fetch("reaction")
        if !DiscourseReactions::Reaction.valid?(reaction)
          raise DiscourseMcp::ToolError, I18n.t("discourse_reactions.errors.reaction_unavailable")
        end
        DiscourseReactions::ReactionManager.new(
          reaction_value: reaction,
          user: request_context.user,
          post: post,
        ).toggle!
        DiscourseMcp::ToolHelpers.text_and_structured(post_id: post.id, reaction: reaction)
      end
    end
  end
end
