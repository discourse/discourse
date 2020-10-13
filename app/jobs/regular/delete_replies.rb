# frozen_string_literal: true

module Jobs
  class DeleteReplies < ::Jobs::Base

    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id] || args[:topic_status_update_id])

      topic = topic_timer&.topic

      if topic_timer.blank? || topic.blank? || topic_timer.execute_at > Time.zone.now
        return
      end

      unless Guardian.new(topic_timer.user).is_staff?
        topic_timer.trash!(Discourse.system_user)
        return
      end

      replies = topic.posts.where("posts.post_number > 1")
      replies.where('posts.created_at < ?', topic_timer.duration.days.ago).each do |post|
        PostDestroyer.new(topic_timer.user, post, context: I18n.t("topic_statuses.auto_deleted_by_timer")).destroy
      end

      topic_timer.execute_at = (replies.minimum(:created_at) || Time.zone.now) + topic_timer.duration.days
      topic_timer.save
    end

  end
end
