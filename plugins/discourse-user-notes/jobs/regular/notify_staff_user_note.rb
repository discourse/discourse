# frozen_string_literal: true

module Jobs
  class NotifyStaffUserNote < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.user_notes_enabled?
      groups = SiteSetting.user_notes_notification_groups_map
      return if groups.empty?

      user = User.find_by(id: args[:user_id])
      return if !user

      note = DiscourseUserNotes.notes_for(user.id).find { |entry| entry[:id] == args[:note_id] }
      return if !note

      DistributedMutex.synchronize("staff-user-note-#{note[:id]}") do
        type = Notification.types[:staff_user_note]
        recipients =
          User
            .human_users
            .where(active: true)
            .where("admin OR moderator")
            .where("suspended_till IS NULL OR suspended_till <= ?", Time.current)
            .where.not(id: note[:created_by])

        if groups.exclude?(Group::AUTO_GROUPS[:logged_in_users]) &&
             (
               groups.exclude?(Group::AUTO_GROUPS[:everyone]) ||
                 SiteSetting.granular_anonymous_and_logged_in_groups_permissions
             )
          recipients = recipients.where(id: GroupUser.where(group_id: groups).select(:user_id))
        end

        notified_user_ids =
          Notification
            .where(notification_type: type, user_id: recipients.select(:id))
            .where("data::jsonb ->> 'user_note_id' = ?", note[:id])
            .select(:user_id)
        recipients = recipients.where.not(id: notified_user_ids)

        data = { username: user.username, user_note_id: note[:id] }.to_json
        records =
          recipients.pluck(:id).map { |user_id| { user_id:, notification_type: type, data: } }
        Notification::Action::BulkCreate.call(records:, skip_send_email: true) if records.present?
      end
    end
  end
end
