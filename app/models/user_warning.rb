class UserWarning < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  belongs_to :created_by, class_name: 'User'
end

# == Schema Information
#
# Table name: user_warnings
#
#  id            :integer          not null, primary key
#  topic_id      :integer          not null
#  user_id       :integer          not null
#  created_by_id :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_user_warnings_on_topic_id  (topic_id) UNIQUE
#  index_user_warnings_on_user_id   (user_id)
#
