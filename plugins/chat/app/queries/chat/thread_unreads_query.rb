# frozen_string_literal: true

module Chat
  ##
  # Handles counting unread messages scoped to threads for a list
  # of channels. A list of thread IDs can be provided to further focus the query.
  # Alternatively, a list of thread IDs can be provided by itself to only get
  # specific threads regardless of channel.
  #
  # This is used for unread indicators in the chat UI. By default only the
  # threads that the user is a member of will be counted and returned in
  # the result. Only threads inside a channel that has threading_enabled
  # will be counted.
  class ThreadUnreadsQuery
    # NOTE: This is arbitrary at this point in time, we may want to increase
    # or decrease this as we find performance issues.
    MAX_THREADS = 3000

    ##
    # @param channel_ids [Array<Integer>] (Optional) The IDs of the channels to count threads for.
    #  If only this is provided, all threads across the channels provided will be counted.
    # @param thread_ids [Array<Integer>] (Optional) The IDs of the threads to count. If this
    #  is used in tandem with channel_ids, it will just further filter the results of
    #  the thread counts from those channels.
    # @param user_id [Integer] The ID of the user to count for.
    # @param include_missing_memberships [Boolean] Whether to include threads
    #   that the user is not a member of. These counts will always be 0.
    # @param include_read [Boolean] Whether to include threads that the user
    #   is a member of where they have read all the messages. This overrides
    #   include_missing_memberships.
    def self.call(
      channel_ids: nil,
      thread_ids: nil,
      user_id:,
      include_missing_memberships: false,
      include_read: true
    )
      return [] if channel_ids.blank? && thread_ids.blank?

      sql = <<~SQL
        SELECT (
          SELECT COUNT(*) AS unread_count
          FROM chat_messages
          INNER JOIN chat_channels ON chat_channels.id = chat_messages.chat_channel_id
          INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id AND chat_threads.channel_id = chat_messages.chat_channel_id
          INNER JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = chat_threads.id
          INNER JOIN user_chat_channel_memberships ON user_chat_channel_memberships.chat_channel_id = chat_messages.chat_channel_id
          INNER JOIN chat_messages AS original_message ON original_message.id = chat_threads.original_message_id
          WHERE chat_messages.thread_id = memberships.thread_id
          AND chat_messages.user_id != :user_id
          AND user_chat_thread_memberships.user_id = :user_id
          AND chat_messages.id > COALESCE(user_chat_thread_memberships.last_read_message_id, 0)
          AND chat_messages.deleted_at IS NULL
          AND chat_messages.thread_id IS NOT NULL
          AND chat_messages.id != chat_threads.original_message_id
          AND (chat_channels.threading_enabled OR chat_threads.force = true)
          AND user_chat_thread_memberships.notification_level = :tracking_level
          AND original_message.deleted_at IS NULL
          AND user_chat_channel_memberships.muted = false
          AND user_chat_channel_memberships.user_id = :user_id
        ) AS unread_count,
        (
          SELECT COUNT(*) AS mention_count
          FROM notifications
          INNER JOIN chat_messages ON chat_messages.id = (data::json->>'chat_message_id')::bigint
          INNER JOIN chat_channels ON chat_channels.id = chat_messages.chat_channel_id
          INNER JOIN user_chat_channel_memberships ON user_chat_channel_memberships.chat_channel_id = chat_messages.chat_channel_id
          LEFT JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
          WHERE NOT read
          AND notifications.user_id = :user_id
          AND notifications.notification_type = :notification_type_mention
          AND user_chat_channel_memberships.user_id = :user_id
          AND chat_channels.threading_enabled
          AND chat_messages.deleted_at IS NULL
          AND NOT user_chat_channel_memberships.muted
        ) AS mention_count,
        (
          SELECT COUNT(*) AS watched_threads_unread_count
          FROM chat_messages
          INNER JOIN chat_channels ON chat_channels.id = chat_messages.chat_channel_id
          INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id AND chat_threads.channel_id = chat_messages.chat_channel_id
          INNER JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = chat_threads.id
          INNER JOIN user_chat_channel_memberships ON user_chat_channel_memberships.chat_channel_id = chat_messages.chat_channel_id
          INNER JOIN chat_messages AS original_message ON original_message.id = chat_threads.original_message_id
          WHERE chat_messages.thread_id = memberships.thread_id
          AND chat_messages.user_id != :user_id
          AND user_chat_thread_memberships.user_id = :user_id
          AND chat_messages.id > COALESCE(user_chat_thread_memberships.last_read_message_id, 0)
          AND chat_messages.deleted_at IS NULL
          AND chat_messages.thread_id IS NOT NULL
          AND chat_messages.id != chat_threads.original_message_id
          AND (chat_channels.threading_enabled OR chat_threads.force = true)
          AND user_chat_thread_memberships.notification_level = :watching_level
          AND original_message.deleted_at IS NULL
          AND user_chat_channel_memberships.user_id = :user_id
          AND NOT user_chat_channel_memberships.muted
        ) AS watched_threads_unread_count,
        chat_threads.channel_id,
        memberships.thread_id
        FROM user_chat_thread_memberships AS memberships
        INNER JOIN chat_threads ON chat_threads.id = memberships.thread_id
        WHERE memberships.user_id = :user_id
        #{channel_ids.present? ? "AND chat_threads.channel_id IN (:channel_ids)" : ""}
        #{thread_ids.present? ? "AND chat_threads.id IN (:thread_ids)" : ""}
        GROUP BY memberships.thread_id, chat_threads.channel_id
        #{include_missing_memberships ? "" : "LIMIT :limit"}
      SQL

      sql = <<~SQL if !include_read
          SELECT * FROM (
            #{sql}
          ) AS thread_tracking
          WHERE (unread_count > 0 OR mention_count > 0 OR watched_threads_unread_count > 0)
        SQL

      sql += <<~SQL if include_missing_memberships && include_read
        UNION ALL
        SELECT 0 AS unread_count, 0 AS mention_count, 0 AS watched_threads_unread_count, chat_threads.channel_id, chat_threads.id AS thread_id
        FROM chat_channels
        INNER JOIN chat_threads ON chat_threads.channel_id = chat_channels.id
        LEFT JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = chat_threads.id
          AND user_chat_thread_memberships.user_id = :user_id
        WHERE user_chat_thread_memberships.id IS NULL
        #{channel_ids.present? ? "AND chat_threads.channel_id IN (:channel_ids)" : ""}
        #{thread_ids.present? ? "AND chat_threads.id IN (:thread_ids)" : ""}
        GROUP BY chat_threads.id
        LIMIT :limit
      SQL

      DB.query(
        sql,
        channel_ids: channel_ids,
        thread_ids: thread_ids,
        user_id: user_id,
        notification_type: ::Notification.types[:chat_mention],
        limit: MAX_THREADS,
        tracking_level: ::Chat::UserChatThreadMembership.notification_levels[:tracking],
        watching_level: ::Chat::UserChatThreadMembership.notification_levels[:watching],
        notification_type_mention: ::Notification.types[:chat_mention],
      )
    end
  end
end
