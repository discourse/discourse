# frozen_string_literal: true

class ReviewableHistory < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :created_by, class_name: "User"

  enum :status, { pending: 0, approved: 1, rejected: 2, ignored: 3, deleted: 4 }

  alias_attribute :type, :reviewable_history_type
  enum :type, { created: 0, transitioned: 1, edited: 2, claimed: 3, unclaimed: 4 }

  after_create_commit :enqueue_staff_queued_post_notification

  def staff_queued_post_notification_groups
    return unless transitioned?

    if approved?
      SiteSetting.staff_queued_post_approval_notification_groups_map
    elsif rejected?
      SiteSetting.staff_queued_post_rejection_notification_groups_map
    end
  end

  private

  def enqueue_staff_queued_post_notification
    if staff_queued_post_notification_groups.present? && reviewable.is_a?(ReviewableQueuedPost)
      Jobs.enqueue(:notify_staff_queued_post_review, history_id: id)
    end
  end
end

# == Schema Information
#
# Table name: reviewable_histories
#
#  id                      :bigint           not null, primary key
#  edited                  :json
#  reviewable_history_type :integer          not null
#  status                  :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  created_by_id           :integer          not null
#  reviewable_id           :integer          not null
#
# Indexes
#
#  index_reviewable_histories_on_created_by_id  (created_by_id)
#  index_reviewable_histories_on_reviewable_id  (reviewable_id)
#
