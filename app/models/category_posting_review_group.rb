# frozen_string_literal: true

class CategoryPostingReviewGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group

  validates :category, presence: true
  validates :group, presence: true
  validate :only_everyone_group_with_required_permission

  enum :post_type, { topic: 0, reply: 1 }
  enum :permission, { exempt: 0, required: 1 }

  private

  def only_everyone_group_with_required_permission
    if group_id != Group::AUTO_GROUPS[:everyone]
      errors.add(
        :base,
        "Group-based approval permissions for specific groups are not supported yet",
      )
    end
  end
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
