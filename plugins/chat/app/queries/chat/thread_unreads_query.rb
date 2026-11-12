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
    # Cap on threads counted in a single call. Heavily-tracked users can have
    # tens of thousands of memberships; computing per-thread counts for all of
    # them blows past the worker timeout. We deliberately trade fidelity for
    # latency: only the most-recently-active threads (by chat_threads.last_message_id)
    # are included in the result. Threads outside the top MAX_THREADS are
    # omitted entirely (no row returned) — acceptable for the unread-indicator
    # UI this drives. Callers passing an explicit thread_ids list are unaffected
    # because the LIMIT is applied after the thread_ids filter.
    MAX_THREADS = 500

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

      # The CTE picks the candidate thread set up front — at most MAX_THREADS,
      # ordered by recency — and resolves the static per-thread filters
      # (muted channel, threading_enabled, force) into columns. The two
      # LATERAL aggregates then run once per candidate, instead of three
      # correlated subqueries running per row of every membership the user has.
      #
      # The user_chat_channel_memberships join is INNER on purpose: a thread
      # membership can outlive channel access (group removal, leave, etc.),
      # and we must not surface unread/mention metadata for a channel the
      # user can no longer access.
      sql = <<~SQL
        WITH limited_memberships AS (
          SELECT
            memberships.thread_id,
            memberships.last_read_message_id,
            memberships.notification_level,
            chat_threads.channel_id,
            chat_threads.original_message_id,
            chat_threads.force,
            chat_channels.threading_enabled,
            uccm.muted AS channel_muted
          FROM user_chat_thread_memberships AS memberships
          INNER JOIN chat_threads ON chat_threads.id = memberships.thread_id
          INNER JOIN chat_channels ON chat_channels.id = chat_threads.channel_id
          INNER JOIN user_chat_channel_memberships AS uccm
                  ON uccm.chat_channel_id = chat_channels.id
                 AND uccm.user_id = :user_id
          WHERE memberships.user_id = :user_id
          #{channel_ids.present? ? "AND chat_threads.channel_id IN (:channel_ids)" : ""}
          #{thread_ids.present? ? "AND chat_threads.id IN (:thread_ids)" : ""}
          ORDER BY chat_threads.last_message_id DESC NULLS LAST
          LIMIT :limit
        )
        SELECT
          CASE WHEN lm.notification_level = :tracking_level
               THEN COALESCE(unread_calc.cnt, 0) ELSE 0 END AS unread_count,
          COALESCE(mention_calc.cnt, 0) AS mention_count,
          CASE WHEN lm.notification_level = :watching_level
               THEN COALESCE(unread_calc.cnt, 0) ELSE 0 END AS watched_threads_unread_count,
          lm.channel_id,
          lm.thread_id
        FROM limited_memberships lm
        LEFT JOIN LATERAL (
          SELECT COUNT(*) AS cnt
          FROM chat_messages cm
          WHERE cm.thread_id = lm.thread_id
            AND cm.user_id != :user_id
            AND cm.id > COALESCE(lm.last_read_message_id, 0)
            AND cm.deleted_at IS NULL
            AND cm.id != lm.original_message_id
            AND NOT lm.channel_muted
            AND (lm.threading_enabled OR lm.force)
            AND EXISTS (
              SELECT 1 FROM chat_messages om
              WHERE om.id = lm.original_message_id AND om.deleted_at IS NULL
            )
        ) unread_calc ON true
        LEFT JOIN LATERAL (
          SELECT COUNT(*) AS cnt
          FROM notifications n
          INNER JOIN chat_messages cm ON cm.id = (n.data::json->>'chat_message_id')::bigint
          WHERE n.user_id = :user_id
            AND n.notification_type = :notification_type_mention
            AND NOT n.read
            AND cm.thread_id = lm.thread_id
            AND cm.deleted_at IS NULL
            AND cm.id > COALESCE(lm.last_read_message_id, 0)
            AND lm.threading_enabled
            AND NOT lm.channel_muted
        ) mention_calc ON true
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
        limit: MAX_THREADS,
        tracking_level: ::Chat::UserChatThreadMembership.notification_levels[:tracking],
        watching_level: ::Chat::UserChatThreadMembership.notification_levels[:watching],
        notification_type_mention: ::Notification.types[:chat_mention],
      )
    end
  end
end
