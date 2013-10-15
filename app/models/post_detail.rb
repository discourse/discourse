class PostDetail < ActiveRecord::Base
  belongs_to :post

  validates_presence_of   :key, :value
  validates_uniqueness_of :key, scope: :post_id
end
