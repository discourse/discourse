# frozen_string_literal: true

module Jobs
  class TopicReminder < ::Jobs::Base

    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id])

      topic = topic_timer&.topic
      user = topic_timer&.user

      if topic_timer.blank? || topic.blank? || user.blank? ||
          topic_timer.execute_at > Time.zone.now
        return
      end

      user.notifications.create!(
        notification_type: Notification.types[:topic_reminder],
        topic_id: topic.id,
        post_number: 1,
        data: { topic_title: topic.title, display_username: user.username }.to_json
      )

      topic_timer.trash!(Discourse.system_user)
    end

  end
end
