# frozen_string_literal: true

module DiscourseBoosts
  module NotificationConsolidation
    def self.boosted_by_multiple_users_plan
      Notifications::DeletePreviousNotifications
        .new(
          type: Notification.types[:boost],
          previous_query_blk:
            Proc.new do |notifications, data|
              notifications.where(id: data[:previous_notification_id])
            end,
        )
        .set_mutations(
          set_data_blk:
            Proc.new do |notification|
              existing =
                Notification
                  .where(user: notification.user)
                  .order("notifications.id DESC")
                  .where(topic_id: notification.topic_id, post_number: notification.post_number)
                  .where(notification_type: notification.notification_type)
                  .where("created_at > ?", 1.day.ago)
                  .first

              data = notification.data_hash
              if existing
                existing_data = existing.data_hash
                existing_usernames =
                  existing_data[:unique_usernames] || [existing_data[:display_username]]
                unique_usernames = (existing_usernames | [data[:display_username]]).map(&:to_s)

                data.merge(
                  previous_notification_id: existing.id,
                  username2: existing_data[:display_username],
                  name2: existing_data[:display_name],
                  count: (existing_data[:count] || 1).to_i + 1,
                  unique_usernames: unique_usernames,
                )
              else
                data
              end
            end,
        )
        .set_precondition(
          precondition_blk:
            Proc.new { |data, _notification| data[:previous_notification_id].present? },
        )
    end
  end
end
