class UserArchivedMessage < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
end

# == Schema Information
#
# Table name: user_archived_messages
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  topic_id   :integer          not null
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_user_archived_messages_on_user_id_and_topic_id  (user_id,topic_id) UNIQUE
#
