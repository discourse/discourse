# frozen_string_literal: true

class GroupPrivateMessageArchiver
  def self.move_to_inbox!(group_id, topic, opts = {})
    topic_id = topic.id

    TopicAllowedGroup
      .find_by(group_id: group_id, topic_id: topic_id)
      .update!(archived_at: nil)

    trigger(:move_to_inbox, group_id, topic)
    MessageBus.publish("/topic/#{topic_id}", { type: "move_to_inbox" }, group_ids: [group_id])
    publish_topic_tracking_state(topic, group_id, opts[:acting_user_id])
    set_imap_sync(topic_id) if !opts[:skip_imap_sync]
  end

  def self.archive!(group_id, topic, opts = {})
    topic_id = topic.id

    TopicAllowedGroup
      .find_by(group_id: group_id, topic_id: topic_id)
      .update!(archived_at: Time.zone.now)

    trigger(:archive_message, group_id, topic)
    MessageBus.publish("/topic/#{topic_id}", { type: "archived" }, group_ids: [group_id])
    publish_topic_tracking_state(topic, group_id, opts[:acting_user_id])
    set_imap_sync(topic_id) if !opts[:skip_imap_sync]
  end

  def self.trigger(event, group_id, topic)
    if group = Group.find_by(id: group_id)
      DiscourseEvent.trigger(event, group: group, topic: topic)
    end
  end

  def self.set_imap_sync(topic_id)
    IncomingEmail.joins(:post)
      .where.not(imap_uid: nil)
      .where(topic_id: topic_id, posts: { post_number: 1 })
      .update_all(imap_sync: true)
  end
  private_class_method :set_imap_sync

  def self.publish_topic_tracking_state(topic, group_id, acting_user_id = nil)
    PrivateMessageTopicTrackingState.publish_group_archived(
      topic: topic,
      group_id: group_id,
      acting_user_id: acting_user_id
    )
  end
  private_class_method :publish_topic_tracking_state
end
