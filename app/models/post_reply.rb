class PostReply < ActiveRecord::Base
  belongs_to :post
  belongs_to :reply, class_name: 'Post'

  validates_uniqueness_of :reply_id, scope: :post_id
end
