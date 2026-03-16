# frozen_string_literal: true

class CategoryPostingReviewGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group

  validates :category, presence: true
  validates :group, presence: true

  enum :post_type, { topic: 0, reply: 1 }
  enum :permission, { exempt: 0, required: 1 }
end

# == Schema Information
#
# Table name: category_posting_review_groups
#
#  id          :bigint           not null, primary key
#  permission  :integer          not null
#  post_type   :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  category_id :integer          not null
#  group_id    :integer          not null
#
# Indexes
#
#  idx_category_posting_review_groups_unique  (category_id,group_id,post_type) UNIQUE
#
