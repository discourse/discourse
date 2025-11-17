# frozen_string_literal: true

##
# Logs individual actions performed on a reviewable item.
#
# When the new reviewable UI is enabled, reviewables may require multiple actions
# (e.g., both a post action and a user action) before the reviewable status is finalized.
# This model tracks each action performed, allowing the system to calculate the final
# status once all required action bundles have been addressed.
#
class ReviewableActionLog < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :performed_by, class_name: "User"

  validates :reviewable_id, presence: true
  validates :action_key, presence: true
  validates :status, presence: true
  validates :performed_by_id, presence: true

  enum :status, Reviewable.statuses.dup, prefix: :status, scopes: false

  ##
  # Calculates the final reviewable status based on a collection of action logs.
  #
  # Business rules:
  # - If all logs are ignored, return ignored
  # - If all logs are rejected, return rejected
  # - If any log is approved, return approved
  # - Otherwise, return pending (not enough actions performed yet)
  #
  # @param logs [ActiveRecord::Relation<ReviewableActionLog>] The action logs to evaluate
  # @return [Symbol] The calculated final status (:ignored, :rejected, :approved, or :pending)
  #
  def self.calculate_final_status(logs)
    statuses = logs.pluck(:status).uniq

    return :ignored if statuses.all? { |s| s == "ignored" || s == self.statuses["ignored"] }
    return :rejected if statuses.all? { |s| s == "rejected" || s == self.statuses["rejected"] }
    return :approved if statuses.any? { |s| s == "approved" || s == self.statuses["approved"] }

    # Default to pending if not all required actions have been performed yet
    :pending
  end
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
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_reviewable_action_logs_on_performed_by_id  (performed_by_id)
#  index_reviewable_action_logs_on_reviewable_id    (reviewable_id)
#
