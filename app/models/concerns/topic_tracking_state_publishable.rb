# frozen_string_literal: true

module TopicTrackingStatePublishable
  extend ActiveSupport::Concern

  class_methods do
    def publish_read_message(
      message_type:,
      channel_name:,
      topic_id:,
      user:,
      last_read_post_number:,
      notification_level: nil
    )
      highest_post_number =
        DB.query_single(
          "SELECT #{user.whisperer? ? "highest_staff_post_number" : "highest_post_number"} FROM topics WHERE id = ?",
          topic_id,
        ).first

      message = {
        message_type: message_type,
        topic_id: topic_id,
        payload: {
          last_read_post_number: last_read_post_number,
          notification_level: notification_level,
          highest_post_number: highest_post_number,
        },
      }.as_json

      MessageBus.publish(channel_name, message, user_ids: [user.id])
    end
  end
end
