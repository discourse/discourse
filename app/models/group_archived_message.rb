class GroupArchivedMessage < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
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
