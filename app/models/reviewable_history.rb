# frozen_string_literal: true

class ReviewableHistory < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :created_by, class_name: "User"

  enum :status, { pending: 0, approved: 1, rejected: 2, ignored: 3, deleted: 4 }

  alias_attribute :type, :reviewable_history_type
  enum :type, { created: 0, transitioned: 1, edited: 2, claimed: 3, unclaimed: 4 }
end

# == Schema Information
#
# Table name: reviewable_histories
#
#  id                      :bigint           not null, primary key
#  reviewable_id           :integer          not null
#  reviewable_history_type :integer          not null
#  status                  :integer          not null
#  created_by_id           :integer          not null
#  edited                  :json
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_reviewable_histories_on_created_by_id  (created_by_id)
#  index_reviewable_histories_on_reviewable_id  (reviewable_id)
#
