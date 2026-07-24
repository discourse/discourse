# frozen_string_literal: true

class PostDetail < ActiveRecord::Base
  belongs_to :post

  validates :key, :value, presence: true
  validates :key, uniqueness: { scope: :post_id }
end

# == Schema Information
#
# Table name: post_details
#
#  id         :integer          not null, primary key
#  extra      :text
#  key        :string
#  value      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :integer
#
# Indexes
#
#  index_post_details_on_post_id_and_key  (post_id,key) UNIQUE
#
