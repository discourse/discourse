# frozen_string_literal: true

module Jobs
  class NotifyStaffQueuedPostReview < ::Jobs::Base
    def execute(args)
      history = ReviewableHistory.includes(:reviewable).find_by(id: args[:history_id])
      groups = history&.staff_queued_post_notification_groups
      return if groups.blank? || !history.reviewable.is_a?(ReviewableQueuedPost)

      DistributedMutex.synchronize("notify_staff_queued_post_review_#{history.id}") do
        notify_staff(history, groups)
      end
    end

    private

    def notify_staff(history, groups)
      notification_type = Notification.types[:staff_queued_post_review]
      data = {
        reviewable_id: history.reviewable_id,
        reviewable_history_id: history.id,
        outcome: history.status,
      }.to_json
      notified_ids = Notification.where(notification_type:, data:).pluck(:user_id)
      staff =
        User
          .human_users
          .where(id: GroupUser.where(group_id: groups).select(:user_id), active: true)
          .where("admin OR moderator")
          .where("suspended_till IS NULL OR suspended_till <= ?", Time.zone.now)
          .where.not(id: [history.created_by_id, *notified_ids])

      staff.find_in_batches do |batch|
        records =
          batch.filter_map do |user|
            if Reviewable.viewable_by(user, preload: false).exists?(history.reviewable_id)
              { user_id: user.id, notification_type:, data: }
            end
          end
        Notification::Action::BulkCreate.call(records:, skip_send_email: true)
      end
    end
  end
end
