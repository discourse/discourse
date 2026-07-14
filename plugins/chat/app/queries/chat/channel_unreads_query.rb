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
      # The CTE picks the candidate channel set up front and resolves the
      # static per-channel filters (chatable_type, threading_enabled, muted,
      # last_read_message_id) into columns. The three LATERAL aggregates then
      # run once per candidate, instead of three correlated subqueries each
      # joining tables that explode with the user's full membership lists.
      #
      # The unread_count aggregate is split into three additive pieces so the
      # planner can use index-friendly filters per piece, instead of an
      # OR-bag that forces a sequential scan over every message past
      # last_read_message_id (the previous bottleneck).
      sql = <<~SQL
        WITH limited_channels AS (
          SELECT
            memberships.chat_channel_id,
            memberships.last_read_message_id,
            memberships.muted,
            chat_channels.chatable_type,
            chat_channels.threading_enabled
          FROM user_chat_channel_memberships AS memberships
          INNER JOIN chat_channels ON chat_channels.id = memberships.chat_channel_id
          WHERE memberships.user_id = :user_id
            AND memberships.chat_channel_id IN (:channel_ids)
          LIMIT :limit
        )
        SELECT
          lc.chat_channel_id AS channel_id,
          CASE WHEN lc.muted THEN 0 ELSE COALESCE(unread_calc.cnt, 0) END AS unread_count,
          COALESCE(mention_calc.cnt, 0) AS mention_count,
          COALESCE(watched_calc.cnt, 0) AS watched_threads_unread_count
        FROM limited_channels lc
        LEFT JOIN LATERAL (
          SELECT
            -- (1) Standalone channel messages (not in any thread).
            (
              SELECT COUNT(*)
              FROM chat_messages cm
              WHERE cm.chat_channel_id = lc.chat_channel_id
                AND cm.thread_id IS NULL
                AND cm.id > COALESCE(lc.last_read_message_id, 0)
                AND cm.deleted_at IS NULL
            )
            +
            -- (2) Thread original messages, which count at the channel level.
            (
              SELECT COUNT(*)
              FROM chat_threads ct
              INNER JOIN chat_messages cm ON cm.id = ct.original_message_id
              WHERE ct.channel_id = lc.chat_channel_id
                AND ct.original_message_id > COALESCE(lc.last_read_message_id, 0)
                AND cm.deleted_at IS NULL
            )
            +
            -- (3) DM channel + threading disabled: thread replies the user is
            -- a member of and hasn't read. Only fires for DM channels with
            -- threading off (auto-enrolled DM threads).
            (
              SELECT COUNT(*)
              FROM chat_messages cm
              INNER JOIN chat_threads ct ON ct.id = cm.thread_id
              INNER JOIN user_chat_thread_memberships uctm
                      ON uctm.thread_id = cm.thread_id
                     AND uctm.user_id = :user_id
              WHERE lc.chatable_type = 'DirectMessage'
                AND NOT lc.threading_enabled
                AND cm.chat_channel_id = lc.chat_channel_id
                AND cm.thread_id IS NOT NULL
                AND cm.id != ct.original_message_id
                AND cm.id > COALESCE(lc.last_read_message_id, 0)
                AND cm.id > COALESCE(uctm.last_read_message_id, 0)
                AND cm.user_id != :user_id
                AND cm.deleted_at IS NULL
            ) AS cnt
        ) unread_calc ON true
        LEFT JOIN LATERAL (
          SELECT COUNT(*) AS cnt
          FROM notifications n
          INNER JOIN chat_messages cm ON cm.id = (n.data::json->>'chat_message_id')::bigint
          LEFT JOIN chat_threads ct ON ct.id = cm.thread_id
          LEFT JOIN user_chat_thread_memberships uctm
                 ON uctm.thread_id = cm.thread_id AND uctm.user_id = :user_id
          WHERE n.user_id = :user_id
            AND n.notification_type = :notification_type_mention
            AND NOT n.read
            AND (n.data::json->>'chat_channel_id')::bigint = lc.chat_channel_id
            AND (
              ((cm.thread_id IS NULL OR cm.id = ct.original_message_id)
                AND cm.id > COALESCE(lc.last_read_message_id, 0))
              OR (cm.thread_id IS NOT NULL
                AND uctm.id IS NOT NULL
                AND cm.id > COALESCE(uctm.last_read_message_id, 0))
            )
        ) mention_calc ON true
        LEFT JOIN LATERAL (
          SELECT COUNT(*) AS cnt
          FROM chat_threads ct
          INNER JOIN user_chat_thread_memberships uctm
                  ON uctm.thread_id = ct.id
                 AND uctm.user_id = :user_id
                 AND uctm.notification_level = :watching_level
          INNER JOIN chat_messages cm
                  ON cm.thread_id = ct.id
                 AND cm.chat_channel_id = lc.chat_channel_id
          WHERE ct.channel_id = lc.chat_channel_id
            AND (lc.threading_enabled OR ct.force)
            AND cm.id != ct.original_message_id
            AND cm.user_id != :user_id
            AND cm.deleted_at IS NULL
            AND cm.id > COALESCE(uctm.last_read_message_id, 0)
        ) watched_calc ON true
      SQL

      sql = <<~SQL if !include_read
        SELECT * FROM (
          #{sql}
        ) AS channel_tracking
        WHERE (unread_count > 0 OR mention_count > 0 OR watched_threads_unread_count > 0)
      SQL

      sql += <<~SQL if include_missing_memberships && include_read
        UNION ALL
        SELECT chat_channels.id AS channel_id, 0 AS unread_count, 0 AS mention_count, 0 AS watched_threads_unread_count
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
