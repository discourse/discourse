# frozen_string_literal: true

class CategoryApprovalGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group

  validates :category, presence: true
  validates :group, presence: true
  validates :approval_type, presence: true

  enum :approval_type, { topic: "topic", reply: "reply" }
end

# == Schema Information
#
# Table name: category_approval_groups
#
#  id            :bigint           not null, primary key
#  approval_type :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  category_id   :integer          not null
#  group_id      :integer          not null
#
# Indexes
#
#  idx_category_approval_groups_unique  (category_id,group_id,approval_type) UNIQUE
#
