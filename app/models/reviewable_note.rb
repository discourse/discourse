# frozen_string_literal: true

class ReviewableNote < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :user

  validates :content, presence: true
  validates :reviewable_id, presence: true
  validates :user_id, presence: true

  scope :ordered, -> { order(:created_at) }
end
