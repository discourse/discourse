# frozen_string_literal: true

class UserPrivateMessageArchiver
  def self.move_to_inbox!(user_id, topic)
    topic_id = topic.id

    return if (TopicUser.where(
      user_id: user_id,
      topic_id: topic_id,
      notification_level: TopicUser.notification_levels[:muted]
    ).exists?)

    TopicAllowedUser
      .find_by(user_id: user_id, topic_id: topic_id)
      .update!(archived_at: nil)

    trigger(:move_to_inbox, user_id, topic)

    MessageBus.publish(
      "/topic/#{topic_id}",
      { type: "move_to_inbox" },
      user_ids: [user_id]
    )
  end

  def self.archive!(user_id, topic)
    topic_id = topic.id

    TopicAllowedUser
      .find_by(user_id: user_id, topic_id: topic_id)
      .update!(archived_at: Time.zone.now)

    trigger(:archive_message, user_id, topic)

    MessageBus.publish(
      "/topic/#{topic_id}",
      { type: "archived" },
      user_ids: [user_id]
    )
  end

  def self.trigger(event, user_id, topic)
    if user = User.find_by(id: user_id)
      DiscourseEvent.trigger(event, user: user, topic: topic)
    end
  end
end
