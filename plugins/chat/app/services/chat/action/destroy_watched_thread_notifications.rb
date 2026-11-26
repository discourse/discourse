# frozen_string_literal: true

module Chat
  module Action
    class DestroyWatchedThreadNotifications < Service::ActionBase
      param :original_message_ids, []

      def call
        thread_ids = Chat::Thread.where(original_message_id: original_message_ids).pluck(:id)
        return if thread_ids.empty?

        Notification
          .where(notification_type: Notification.types[:chat_watched_thread])
          .where(
            user_id: Chat::UserChatThreadMembership.where(thread_id: thread_ids).select(:user_id),
          )
          .where("data::json ->> 'chat_thread_id' IN (?)", thread_ids.map(&:to_s))
          .destroy_all
      end
    end
  end
end
