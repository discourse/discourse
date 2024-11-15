# frozen_string_literal: true

module Chat
  ##
  # Handles counting unread messages and mentions for a list of channels.
  # This is used for unread indicators in the chat UI. By default only the
  # channels that the user is a member of will be counted and returned in
  # the result.
  class ChannelUnreadsQuery
    # NOTE: This is arbitrary at this point in time, we may want to increase
    # or decrease this as we find performance issues.
    MAX_CHANNELS = 1000

    ##
    # @param channel_ids [Array<Integer>] The IDs of the channels to count.
    # @param user_id [Integer] The ID of the user to count for.
    # @param include_missing_memberships [Boolean] Whether to include channels
    #   that the user is not a member of. These counts will always be 0.
    # @param include_read [Boolean] Whether to include channels that the user
    #   is a member of where they have read all the messages. This overrides
    #   include_missing_memberships.
    def self.call(channel_ids:, user_id:, include_missing_memberships: false, include_read: true)
      sql = <<~SQL
        SELECT (
          SELECT COUNT(*) AS unread_count
          FROM chat_messages
          INNER JOIN chat_channels ON chat_channels.id = chat_messages.chat_channel_id
          INNER JOIN user_chat_channel_memberships ON user_chat_channel_memberships.chat_channel_id = chat_channels.id
          LEFT JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
          WHERE chat_channels.id = memberships.chat_channel_id
          AND user_chat_channel_memberships.user_id = :user_id
          AND chat_messages.id > COALESCE(user_chat_channel_memberships.last_read_message_id, 0)
          AND chat_messages.deleted_at IS NULL
          AND (chat_messages.thread_id IS NULL OR chat_messages.id = chat_threads.original_message_id)
          AND NOT user_chat_channel_memberships.muted
        ) AS unread_count,
        (
          SELECT COUNT(*) AS mention_count
          FROM notifications
          INNER JOIN user_chat_channel_memberships ON user_chat_channel_memberships.user_id = :user_id
          INNER JOIN chat_messages ON (data::json->>'chat_message_id')::bigint = chat_messages.id
          LEFT JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
          WHERE NOT read
          AND user_chat_channel_memberships.chat_channel_id = memberships.chat_channel_id
          AND notifications.user_id = :user_id
          AND notifications.notification_type = :notification_type_mention
          AND (data::json->>'chat_message_id')::bigint > COALESCE(user_chat_channel_memberships.last_read_message_id, 0)
          AND (data::json->>'chat_channel_id')::bigint = memberships.chat_channel_id
        ) AS mention_count,
        (
          SELECT COUNT(*) AS watched_threads_unread_count
          FROM chat_messages
          INNER JOIN chat_channels ON chat_channels.id = chat_messages.chat_channel_id
          INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id AND chat_threads.channel_id = chat_messages.chat_channel_id
          INNER JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = chat_threads.id
          WHERE chat_messages.chat_channel_id = memberships.chat_channel_id
          AND chat_messages.thread_id = user_chat_thread_memberships.thread_id
          AND chat_messages.user_id != :user_id
          AND chat_messages.deleted_at IS NULL
          AND chat_messages.thread_id IS NOT NULL
          AND chat_messages.id != chat_threads.original_message_id
          AND chat_messages.id > COALESCE(user_chat_thread_memberships.last_read_message_id, 0)
          AND user_chat_thread_memberships.user_id = :user_id
          AND user_chat_thread_memberships.notification_level = :watching_level
          AND (chat_channels.threading_enabled OR chat_threads.force = true)
        ) AS watched_threads_unread_count,
        memberships.chat_channel_id AS channel_id
        FROM user_chat_channel_memberships AS memberships
        WHERE memberships.user_id = :user_id AND memberships.chat_channel_id IN (:channel_ids)
        GROUP BY memberships.chat_channel_id
        #{include_missing_memberships ? "" : "LIMIT :limit"}
      SQL

      sql = <<~SQL if !include_read
        SELECT * FROM (
          #{sql}
        ) AS channel_tracking
        WHERE (unread_count > 0 OR mention_count > 0 OR watched_threads_unread_count > 0)
      SQL

      sql += <<~SQL if include_missing_memberships && include_read
        UNION ALL
        SELECT 0 AS unread_count, 0 AS mention_count, 0 AS watched_threads_unread_count, chat_channels.id AS channel_id
        FROM chat_channels
        LEFT JOIN user_chat_channel_memberships ON user_chat_channel_memberships.chat_channel_id = chat_channels.id
          AND user_chat_channel_memberships.user_id = :user_id
        WHERE chat_channels.id IN (:channel_ids) AND user_chat_channel_memberships.id IS NULL
        GROUP BY chat_channels.id
        LIMIT :limit
      SQL

      DB.query(
        sql,
        channel_ids: channel_ids,
        user_id: user_id,
        notification_type_mention: ::Notification.types[:chat_mention],
        watching_level: ::Chat::UserChatThreadMembership.notification_levels[:watching],
        limit: MAX_CHANNELS,
      )
    end
  end
end
