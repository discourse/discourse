# frozen_string_literal: true

module PostVoting
  class CommentCreator
    def self.create(attributes)
      comment = PostVotingComment.new(attributes)

      ActiveRecord::Base.transaction do
        if comment.save
          create_commented_notification(comment)

          DB.after_commit { publish_changes(comment) }
        end
      end

      comment
    end

    def self.publish_changes(comment)
      Scheduler::Defer.later "Publish new post voting comment" do
        comment.post.publish_change_to_clients!(
          :post_voting_post_commented,
          comment:
            PostVotingCommentSerializer.new(
              comment,
              { scope: anonymous_guardian, root: false },
            ).as_json,
          comments_count: PostVotingComment.where(post_id: comment.post_id).count,
        )
      end
    end

    def self.create_commented_notification(comment)
      return if comment.user_id == comment.post.user_id

      Notification.create!(
        notification_type: Notification.types[:question_answer_user_commented],
        user_id: comment.post.user_id,
        post_number: comment.post.post_number,
        topic_id: comment.post.topic_id,
        data: {
          post_voting_comment_id: comment.id,
          display_username: comment.user.username,
        }.to_json,
      )

      PostAlerter.create_notification_alert(
        user: comment.post.user,
        post: comment.post,
        notification_type: Notification.types[:question_answer_user_commented],
        username: comment.user.username,
      )
    end

    private

    def self.anonymous_guardian
      Guardian.new(nil)
    end
  end
end
