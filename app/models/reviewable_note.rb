# frozen_string_literal: true

class ReviewableNote < ActiveRecord::Base
  MAX_CONTENT_LENGTH = 2000

  belongs_to :reviewable
  belongs_to :user

  validates :content, presence: true, length: { minimum: 1, maximum: MAX_CONTENT_LENGTH }
  validates :reviewable_id, presence: true
  validates :user_id, presence: true

  scope :ordered, -> { order(:created_at) }
end

# == Schema Information
#
# Table name: reviewable_notes
#
#  id            :bigint           not null, primary key
#  reviewable_id :bigint           not null
#  user_id       :bigint           not null
#  content       :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_reviewable_notes_on_reviewable_id                 (reviewable_id)
#  index_reviewable_notes_on_reviewable_id_and_created_at  (reviewable_id,created_at)
#  index_reviewable_notes_on_user_id                       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (reviewable_id => reviewables.id)
#  fk_rails_...  (user_id => users.id)
#
