# frozen_string_literal: true

module Action
  class SuspendSilencePostAction
    def self.call(guardian:, context:)
      return if context.post_id.blank? || context.post_action.blank?

      if post = Post.where(id: context.post_id).first
        case context.post_action
        when "delete"
          PostDestroyer.new(guardian.user, post).destroy if guardian.can_delete_post_or_topic?(post)
        when "delete_replies"
          if guardian.can_delete_post_or_topic?(post)
            PostDestroyer.delete_with_replies(guardian.user, post)
          end
        when "edit"
          revisor = PostRevisor.new(post)

          # Take what the moderator edited in as gospel
          revisor.revise!(
            guardian.user,
            { raw: context.post_edit },
            skip_validations: true,
            skip_revision: true,
          )
        end
      end
    end
  end
end
