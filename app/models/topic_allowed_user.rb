class TopicAllowedUser < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

  validates_uniqueness_of :topic_id, scope: :user_id
end

# == Schema Information
#
# Table name: topic_allowed_users
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  topic_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_topic_allowed_users_on_topic_id_and_user_id  (topic_id,user_id) UNIQUE
#  index_topic_allowed_users_on_user_id_and_topic_id  (user_id,topic_id) UNIQUE
#
