# frozen_string_literal: true

class CategoryPostingReviewGroup < ActiveRecord::Base
  # TODO: Drop after 20260319054731 has been promoted to pre-deploy
  self.ignored_columns += %w[permission]

  belongs_to :category
  belongs_to :group

  validates :category, presence: true
  validates :group, presence: true

  enum :post_type, { topic: 0, reply: 1 }

  def self.user_in_group?(category:, user:, post_type:)
    where(category: category, post_type: post_type).where(
      group_id: user.group_users.select(:group_id),
    ).exists?
  end
end

# == Schema Information
#
# Table name: category_posting_review_groups
#
#  id          :bigint           not null, primary key
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
