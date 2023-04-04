# frozen_string_literal: true

class PostDetail < ActiveRecord::Base
  belongs_to :post

  validates_presence_of :key, :value
  validates_uniqueness_of :key, scope: :post_id
end

# == Schema Information
#
# Table name: post_details
#
#  id         :integer          not null, primary key
#  post_id    :integer
#  key        :string
#  value      :string
#  extra      :string(1000000)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_post_details_on_post_id_and_key  (post_id,key) UNIQUE
#
