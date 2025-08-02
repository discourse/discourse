# frozen_string_literal: true

class GroupArchivedMessage < ActiveRecord::Base
  belongs_to :group
  belongs_to :topic

  def self.move_to_inbox!(group_id, topic, opts = {})
    topic_id = topic.id
    destroyed = GroupArchivedMessage.where(group_id: group_id, topic_id: topic_id).destroy_all
    trigger(:move_to_inbox, group_id, topic_id)
    MessageBus.publish("/topic/#{topic_id}", { type: "move_to_inbox" }, group_ids: [group_id])
    publish_topic_tracking_state(topic, group_id, opts[:acting_user_id])
    set_imap_sync(topic_id) if !opts[:skip_imap_sync] && destroyed.present?
    Jobs.enqueue(
      :group_pm_update_summary,
      group_id: group_id,
      topic_id: topic_id,
      acting_user_id: opts[:acting_user_id],
    )
  end

  def self.archive!(group_id, topic, opts = {})
    topic_id = topic.id
    destroyed = GroupArchivedMessage.where(group_id: group_id, topic_id: topic_id).destroy_all
    GroupArchivedMessage.create!(group_id: group_id, topic_id: topic_id)
    trigger(:archive_message, group_id, topic_id)
    MessageBus.publish("/topic/#{topic_id}", { type: "archived" }, group_ids: [group_id])
    publish_topic_tracking_state(topic, group_id, opts[:acting_user_id])
    set_imap_sync(topic_id) if !opts[:skip_imap_sync] && destroyed.blank?
    Jobs.enqueue(
      :group_pm_update_summary,
      group_id: group_id,
      topic_id: topic_id,
      acting_user_id: opts[:acting_user_id],
    )
  end

  def self.trigger(event, group_id, topic_id)
    group = Group.find_by(id: group_id)
    topic = Topic.find_by(id: topic_id)
    DiscourseEvent.trigger(event, group: group, topic: topic) if group && topic
  end

  def self.set_imap_sync(topic_id)
    IncomingEmail
      .joins(:post)
      .where.not(imap_uid: nil)
      .where(topic_id: topic_id, posts: { post_number: 1 })
      .update_all(imap_sync: true)
  end
  private_class_method :set_imap_sync

  def self.publish_topic_tracking_state(topic, group_id, acting_user_id = nil)
    PrivateMessageTopicTrackingState.publish_group_archived(
      topic: topic,
      group_id: group_id,
      acting_user_id: acting_user_id,
    )
  end
  private_class_method :publish_topic_tracking_state
end

# == Schema Information
#
# Table name: group_archived_messages
#
#  id         :integer          not null, primary key
#  group_id   :integer          not null
#  topic_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_group_archived_messages_on_group_id_and_topic_id  (group_id,topic_id) UNIQUE
#
