class TopicAllowedGroup < ActiveRecord::Base
  belongs_to :topic
  belongs_to :group
  attr_accessible :group_id, :user_id

  validates_uniqueness_of :topic_id, scope: :group_id
end
