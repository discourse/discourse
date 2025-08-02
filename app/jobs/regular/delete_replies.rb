# frozen_string_literal: true

module Jobs
  class DeleteReplies < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      unless Guardian.new(topic_timer.user).is_staff?
        topic_timer.trash!(Discourse.system_user)
        return
      end

      replies = topic.posts.where("posts.post_number > 1")
      replies =
        replies.where(
          "like_count < ?",
          SiteSetting.skip_auto_delete_reply_likes,
        ) if SiteSetting.skip_auto_delete_reply_likes > 0

      replies
        .where("posts.created_at < ?", topic_timer.duration_minutes.minutes.ago)
        .each do |post|
          PostDestroyer.new(
            topic_timer.user,
            post,
            context: I18n.t("topic_statuses.auto_deleted_by_timer"),
          ).destroy
        end

      topic_timer.execute_at =
        (replies.minimum(:created_at) || Time.zone.now) + topic_timer.duration_minutes.minutes
      topic_timer.save
    end
  end
end
