class GroupArchivedMessage < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic

  def self.move_to_inbox!(group_id, topic_id)
    GroupArchivedMessage.where(group_id: group_id, topic_id: topic_id).destroy_all
    MessageBus.publish("/topic/#{topic_id}", {type: "move_to_inbox"}, group_ids: [group_id])
  end

  def self.archive!(group_id, topic_id)
    GroupArchivedMessage.where(group_id: group_id, topic_id: topic_id).destroy_all
    GroupArchivedMessage.create!(group_id: group_id, topic_id: topic_id)
    MessageBus.publish("/topic/#{topic_id}", {type: "archived"}, group_ids: [group_id])
  end

end

# == Schema Information
#
# Table name: group_archived_messages
#
#  id         :integer          not null, primary key
#  group_id   :integer          not null
#  topic_id   :integer          not null
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_group_archived_messages_on_group_id_and_topic_id  (group_id,topic_id) UNIQUE
#
