# frozen_string_literal: true

module Chat
  module NotificationConsolidationExtension
    CONSOLIDATION_THRESHOLD = 1

    def self.watched_thread_message_plan
      Notifications::ConsolidateNotifications.new(
        from: Notification.types[:chat_watched_thread],
        to: Notification.types[:chat_watched_thread],
        threshold: CONSOLIDATION_THRESHOLD,
        unconsolidated_query_blk:
          Proc.new do |notifications, data|
            notifications.where("data::json ->> 'consolidated' IS NULL").where(
              "data::json ->> 'chat_thread_id' = ?",
              data[:chat_thread_id].to_s,
            )
          end,
        consolidated_query_blk:
          Proc.new do |notifications, data|
            notifications.where("(data::json ->> 'consolidated')::bool").where(
              "data::json ->> 'chat_thread_id' = ?",
              data[:chat_thread_id].to_s,
            )
          end,
      ).set_mutations(
        set_data_blk:
          lambda do |notification|
            data = notification.data_hash

            last_watched_thread_notification =
              Notification
                .where(user_id: notification.user_id)
                .order("notifications.id DESC")
                .where("data::json ->> 'chat_thread_id' = ?", data[:chat_thread_id].to_s)
                .where(notification_type: Notification.types[:chat_watched_thread])
                .first

            return data if !last_watched_thread_notification

            consolidated_data = last_watched_thread_notification.data_hash
            prev_acting_id =
              consolidated_data[:acting_user_id] ||
                (
                  if consolidated_data[:username].present?
                    User.where(username_lower: consolidated_data[:username].downcase).pick(:id)
                  end
                )
            prev_user2_id =
              consolidated_data[:user2_id] ||
                (
                  if consolidated_data[:username2].present?
                    User.where(username_lower: consolidated_data[:username2].downcase).pick(:id)
                  end
                )

            if data[:last_read_message_id].to_i <= consolidated_data[:chat_message_id].to_i
              data[:chat_message_id] = consolidated_data[:chat_message_id]
            end

            merged_user_ids = (Array(consolidated_data[:user_ids]) + Array(data[:user_ids])).uniq

            if !prev_user2_id && data[:acting_user_id].to_i != prev_acting_id.to_i
              data.merge(user2_id: prev_acting_id, user_ids: merged_user_ids)
            else
              data.merge(
                acting_user_id: prev_acting_id,
                user2_id: prev_user2_id,
                user_ids: merged_user_ids,
              )
            end
          end,
      )
    end
  end
end
