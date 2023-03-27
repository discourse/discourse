# frozen_string_literal: true

module Chat
  class ChannelUnreadsQuery
    def self.call(channel_id:, user_id:)
      sql = <<~SQL
      SELECT (
      SELECT COUNT(*) AS unread_count
      FROM chat_messages
      INNER JOIN chat_channels ON chat_channels.id = chat_messages.chat_channel_id
      INNER JOIN user_chat_channel_memberships ON user_chat_channel_memberships.chat_channel_id = chat_channels.id
      WHERE chat_channels.id = :channel_id
      AND chat_messages.user_id != :user_id
      AND user_chat_channel_memberships.user_id = :user_id
      AND chat_messages.id > COALESCE(user_chat_channel_memberships.last_read_message_id, 0)
      AND chat_messages.deleted_at IS NULL
    ) AS unread_count,
    (
      SELECT COUNT(*) AS mention_count
      FROM notifications
      INNER JOIN user_chat_channel_memberships ON user_chat_channel_memberships.chat_channel_id = :channel_id
      AND user_chat_channel_memberships.user_id = :user_id
      WHERE NOT read
      AND notifications.user_id = :user_id
      AND notifications.notification_type = :notification_type
      AND (data::json->>'chat_message_id')::bigint > COALESCE(user_chat_channel_memberships.last_read_message_id, 0)
      AND (data::json->>'chat_channel_id')::bigint = :channel_id
    ) AS mention_count;
    SQL

      DB
        .query(
          sql,
          channel_id: channel_id,
          user_id: user_id,
          notification_type: Notification.types[:chat_mention],
        )
        .first
        .to_h
    end
  end
end
