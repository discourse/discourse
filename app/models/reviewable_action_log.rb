# frozen_string_literal: true

class ReviewableActionLog < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :performed_by, class_name: "User"

  validates :action_key, :status, :performed_by_id, presence: true

  enum :status, Reviewable.statuses.dup, prefix: :status, scopes: false
end

# == Schema Information
#
# Table name: reviewable_action_logs
#
#  id              :bigint           not null, primary key
#  reviewable_id   :bigint           not null
#  action_key      :string           not null
#  status          :integer          not null
#  performed_by_id :integer          not null
#  bundle          :string           default("legacy-actions"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_reviewable_action_logs_on_bundle           (bundle)
#  index_reviewable_action_logs_on_performed_by_id  (performed_by_id)
#  index_reviewable_action_logs_on_reviewable_id    (reviewable_id)
#
