# frozen_string_literal: true

module Chat
  module Action
    # When updating the read state of chat channel memberships, we also need
    # to be sure to mark any mention-based notifications read at the same time.
    class MarkMentionsRead < Service::ActionBase
      # @param [User] user The user that we are marking notifications read for.
      # @param [Array] channel_ids The chat channels that are having their notifications
      #   marked as read.
      # @param [Integer] message_id Optional, used to limit the max message ID to mark
      #   mentions read for in the channel.
      # @param [Integer] thread_id Optional, if provided then all notifications related
      #   to messages in the thread will be marked as read.
      param :user
      option :channel_ids, []
      option :message_id, optional: true
      option :thread_id, optional: true

      def call
        ::Notification
          .where(notification_type: Notification.types[:chat_mention])
          .where(user: user)
          .where(read: false)
          .joins(
            "INNER JOIN chat_mention_notifications ON chat_mention_notifications.notification_id = notifications.id",
          )
          .joins(
            "INNER JOIN chat_mentions ON chat_mentions.id = chat_mention_notifications.chat_mention_id",
          )
          .joins("INNER JOIN chat_messages ON chat_mentions.chat_message_id = chat_messages.id")
          .where("chat_messages.chat_channel_id IN (?)", channel_ids)
          .then do |notifications|
            break notifications if message_id.blank? && thread_id.blank?
            break notifications.where("chat_messages.id <= ?", message_id) if message_id.present?
            if thread_id.present?
              notifications.where(
                "chat_messages.id IN (SELECT id FROM chat_messages WHERE thread_id = ?)",
                thread_id,
              )
            end
          end
          .update_all(read: true)
      end
    end
  end
end
