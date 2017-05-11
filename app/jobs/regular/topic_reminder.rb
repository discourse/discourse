module Jobs
  class TopicReminder < Jobs::Base

    def execute(args)
      topic_status_update = TopicStatusUpdate.find_by(id: args[:topic_status_update_id])

      topic = topic_status_update&.topic
      user = topic_status_update&.user

      if topic_status_update.blank? || topic.blank? || user.blank? ||
          topic_status_update.execute_at > Time.zone.now
        return
      end

      user.notifications.create(
        notification_type: Notification.types[:topic_reminder],
        topic_id: topic.id,
        post_number: 1,
        data: { topic_title: topic.title, display_username: user.username }.to_json
      )

      topic_status_update.trash!(Discourse.system_user)

      true
    end

  end
end