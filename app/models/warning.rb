class Warning < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  belongs_to :created_by, class_name: 'User'
end

# == Schema Information
#
# Table name: warnings
#
#  id            :integer          not null, primary key
#  topic_id      :integer          not null
#  user_id       :integer          not null
#  created_by_id :integer          not null
#  created_at    :datetime
#  updated_at    :datetime
#
# Indexes
#
#  index_warnings_on_topic_id  (topic_id) UNIQUE
#  index_warnings_on_user_id   (user_id)
#
