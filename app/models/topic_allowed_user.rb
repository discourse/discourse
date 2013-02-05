class TopicAllowedUser < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user
  attr_accessible :topic_id, :user_id

  validates_uniqueness_of :topic_id, scope: :user_id
end
