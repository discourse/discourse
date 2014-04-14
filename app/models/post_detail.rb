class PostDetail < ActiveRecord::Base
  belongs_to :post

  validates_presence_of   :key, :value
  validates_uniqueness_of :key, scope: :post_id
end

# == Schema Information
#
# Table name: post_details
#
#  id         :integer          not null, primary key
#  post_id    :integer
#  key        :string(255)
#  value      :string(255)
#  extra      :text
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_post_details_on_post_id_and_key  (post_id,key) UNIQUE
#
