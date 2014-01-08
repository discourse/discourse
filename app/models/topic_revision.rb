class TopicRevision < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

  serialize :modifications, Hash
end
