class QueuedPreviewPostMap < ActiveRecord::Base
  belongs_to :post
  belongs_to :topic
  belongs_to :queued_post, class_name: 'QueuedPost', foreign_key: 'queued_id'

  def new_topic?
    topic_id # set if topic is new
  end
end
