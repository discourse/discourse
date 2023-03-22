# frozen_string_literal: true

module Chat
  module Action
    # When updating the read state of chat channel memberships, we also need
    # to be sure to mark any mention-based notifications read at the same time.
    class MarkMentionsRead
      # @param [User] user The user that we are marking notifications read for.
      # @param [Array] channel_ids The chat channels that are having their notifications
      #   marked as read.
      # @param [Integer] message_id Optional, used to limit the max message ID to mark
      #   mentions read for in the channel.
      def self.call(user, channel_ids:, message_id: nil)
        ::Notification
          .where(notification_type: Notification.types[:chat_mention])
          .where(user: user)
          .where(read: false)
          .joins("INNER JOIN chat_mentions ON chat_mentions.notification_id = notifications.id")
          .joins("INNER JOIN chat_messages ON chat_mentions.chat_message_id = chat_messages.id")
          .where("chat_messages.chat_channel_id IN (?)", channel_ids)
          .then do |notifications|
            break notifications if message_id.blank?
            notifications.where("chat_messages.id <= ?", message_id)
          end
          .update_all(read: true)
      end
    end
  end
end
