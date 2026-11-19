# frozen_string_literal: true

module Jobs
  class NotifyStaffReviewableNote < ::Jobs::Base
    def execute(args)
      groups = SiteSetting.reviewable_note_notification_groups_map
      return if groups.empty?

      note = ReviewableNote.find_by(id: args[:note_id])
      return if !note

      DistributedMutex.synchronize("staff-reviewable-note-#{note.id}") do
        notify_staff(note, groups)
      end
    end

    private

    def notify_staff(note, groups)
      type = Notification.types[:staff_reviewable_note]
      notified_user_ids =
        Notification
          .where(notification_type: [type, Notification.types[:mentioned]])
          .where("data::jsonb ->> 'reviewable_note_id' = ?", note.id.to_s)
          .select(:user_id)

      recipients =
        User
          .human_users
          .where(active: true)
          .where("admin OR moderator")
          .where("suspended_till IS NULL OR suspended_till <= ?", Time.current)
          .where(id: GroupUser.where(group_id: groups).select(:user_id))
          .where.not(id: note.user_id)
          .where.not(id: notified_user_ids)

      data = { reviewable_id: note.reviewable_id, reviewable_note_id: note.id }.to_json
      recipients.find_in_batches do |batch|
        records =
          batch.filter_map do |recipient|
            if Reviewable.viewable_by(recipient, preload: false).exists?(note.reviewable_id)
              { user_id: recipient.id, notification_type: type, data: }
            end
          end
        Notification::Action::BulkCreate.call(records:, skip_send_email: true)
      end
    end
  end
end
