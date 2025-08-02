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

            if data[:last_read_message_id].to_i <= consolidated_data[:chat_message_id].to_i
              data[:chat_message_id] = consolidated_data[:chat_message_id]
            end

            if !consolidated_data[:username2] && data[:username] != consolidated_data[:username]
              data.merge(
                username2: consolidated_data[:username],
                user_ids: consolidated_data[:user_ids].concat(data[:user_ids]),
              )
            else
              data.merge(
                username: consolidated_data[:username],
                username2: consolidated_data[:username2],
                user_ids: (consolidated_data[:user_ids].concat(data[:user_ids])).uniq,
              )
            end
          end,
      )
    end
  end
end
