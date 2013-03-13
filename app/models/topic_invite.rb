class TopicInvite < ActiveRecord::Base
  belongs_to :topic
  belongs_to :invite

  validates_presence_of :topic_id
  validates_presence_of :invite_id

  validates_uniqueness_of :topic_id, scope: :invite_id
end
