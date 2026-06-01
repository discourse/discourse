# frozen_string_literal: true

module PostVoting
  module GuardianExtension
    def can_vote_on_post?(post, direction: nil)
      return false if !user
      return false if !post
      return false if !post.is_post_voting_topic?
      return false if !can_see?(post)
      return false if post.user_id == user.id
      return false if post.topic.archived?
      return false if post.topic.closed?
      if direction
        if PostVotingVote.exists?(votable: post, user_id: user.id, direction: direction)
          return false
        end
        return false if !PostVoting::VoteManager.can_undo(post, user)
      end
      true
    end

    def can_edit_comment?(comment)
      return false if !user
      return true if comment.user_id == user.id
      return true if is_admin?
      return true if is_moderator?
      false
    end

    def can_delete_comment?(comment)
      can_edit_comment?(comment)
    end

    def can_flag_post_voting_comments?
      return false if user.silenced?
      return true if user.staff?

      user.in_any_groups?(SiteSetting.flag_posts_voting_comments_allowed_groups_map)
    end

    def can_flag_post_voting_comment?(comment)
      return false if !authenticated? || !comment || comment.trashed? || !comment.user
      return false if !can_see?(comment.post)
      return false if comment.user.staff? && !SiteSetting.allow_flagging_staff
      return false if comment.user_id == @user.id

      can_flag_post_voting_comments?
    end

    def can_flag_post_voting_comment_as?(comment, flag_type_id, opts)
      return false if !is_staff? && (opts[:take_action] || opts[:queue_for_review])

      if flag_type_id == ReviewableScore.types[:notify_user]
        is_warning = ActiveRecord::Type::Boolean.new.deserialize(opts[:is_warning])

        return false if is_warning && !is_staff?
      end

      true
    end
  end
end
