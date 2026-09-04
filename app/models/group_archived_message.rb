# frozen_string_literal: true

class GroupArchivedMessage < ActiveRecord::Base
  belongs_to :group
  belongs_to :topic

  class << self
    def move_to_inbox!(group_id, topic, opts = {})
      return unless topic.private_message? && topic.topic_allowed_groups.exists?(group_id: group_id)

      topic_id = topic.id

      GroupArchivedMessage.where(group_id: group_id, topic_id: topic_id).destroy_all

      trigger(:move_to_inbox, group_id, topic_id)
      MessageBus.publish("/topic/#{topic_id}", { type: "move_to_inbox" }, group_ids: [group_id])
      publish_topic_tracking_state(topic, group_id, opts[:acting_user_id])

      Jobs.enqueue(
        :group_pm_update_summary,
        group_id: group_id,
        topic_id: topic_id,
        acting_user_id: opts[:acting_user_id],
      )
    end

    def archive!(group_id, topic, opts = {})
      return unless topic.private_message? && topic.topic_allowed_groups.exists?(group_id: group_id)

      topic_id = topic.id

      GroupArchivedMessage.where(group_id: group_id, topic_id: topic_id).destroy_all
      GroupArchivedMessage.create!(group_id: group_id, topic_id: topic_id)

      trigger(:archive_message, group_id, topic_id)
      MessageBus.publish("/topic/#{topic_id}", { type: "archived" }, group_ids: [group_id])
      publish_topic_tracking_state(topic, group_id, opts[:acting_user_id])

      Jobs.enqueue(
        :group_pm_update_summary,
        group_id: group_id,
        topic_id: topic_id,
        acting_user_id: opts[:acting_user_id],
      )
    end

    def trigger(event, group_id, topic_id)
      group = Group.find_by(id: group_id)
      topic = Topic.find_by(id: topic_id)
      DiscourseEvent.trigger(event, group: group, topic: topic) if group && topic
    end

    def publish_topic_tracking_state(topic, group_id, acting_user_id = nil)
      PrivateMessageTopicTrackingState.publish_group_archived(
        topic: topic,
        group_id: group_id,
        acting_user_id: acting_user_id,
      )
    end
  end

  private_class_method :publish_topic_tracking_state
end

# == Schema Information
#
# Table name: group_archived_messages
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  group_id   :integer          not null
#  topic_id   :integer          not null
#
# Indexes
#
#  index_group_archived_messages_on_group_id_and_topic_id  (group_id,topic_id) UNIQUE
#
