# frozen_string_literal: true

class CategoryApprovalGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group

  validates :category, presence: true
  validates :group, presence: true
  validates :approval_type, presence: true

  enum :approval_type, { topic: "topic", reply: "reply" }
end
