# frozen_string_literal: true

class GroupArchivedMessage < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic

  def self.move_to_inbox!(group_id, topic)
    topic_id = topic.id
    GroupArchivedMessage.where(group_id: group_id, topic_id: topic_id).destroy_all
    trigger(:move_to_inbox, group_id, topic_id)
    MessageBus.publish("/topic/#{topic_id}", { type: "move_to_inbox" }, group_ids: [group_id])
    publish_topic_tracking_state(topic)
  end

  def self.archive!(group_id, topic)
    topic_id = topic.id
    GroupArchivedMessage.where(group_id: group_id, topic_id: topic_id).destroy_all
    GroupArchivedMessage.create!(group_id: group_id, topic_id: topic_id)
    trigger(:archive_message, group_id, topic_id)
    MessageBus.publish("/topic/#{topic_id}", { type: "archived" }, group_ids: [group_id])
    publish_topic_tracking_state(topic)
  end

  def self.trigger(event, group_id, topic_id)
    group = Group.find_by(id: group_id)
    topic = Topic.find_by(id: topic_id)
    if group && topic
      DiscourseEvent.trigger(event, group: group, topic: topic)
    end
  end

  private

  def self.publish_topic_tracking_state(topic)
    TopicTrackingState.publish_private_message(
      topic, group_archive: true
    )
  end
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
