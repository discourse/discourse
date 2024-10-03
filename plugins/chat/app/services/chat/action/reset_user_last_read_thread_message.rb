# frozen_string_literal: true

module Chat
  module Action
    class ResetUserLastReadThreadMessage < Service::ActionBase
      # @param [Array] last_read_message_ids The message IDs to match with the
      #   last_read_message_ids in UserChatThreadMembership which will be reset
      #   to NULL or the most recent non-deleted message in the thread to
      #   update read state.
      # @param [Integer] thread_ids The thread IDs of the memberships to update,
      #   this is used to find the latest non-deleted message in the thread.
      param :last_read_message_ids, []
      param :thread_ids, []

      def call
        DB.exec(sql_query, last_read_message_ids:, thread_ids:)
      end

      private

      def sql_query
        <<~SQL
         -- update the last_read_message_id to the most recent
         -- non-deleted message in the thread so unread counts are correct.
         -- the cte row_number is necessary to only return a single row
         -- for each thread to prevent additional data being returned
         WITH cte AS (
           SELECT * FROM (
             SELECT id, thread_id, row_number() OVER (
                 PARTITION BY thread_id ORDER BY created_at DESC, id DESC
               ) AS row_number
             FROM chat_messages
             WHERE deleted_at IS NULL AND thread_id IN (:thread_ids) AND chat_messages.id NOT IN (
               SELECT original_message_id FROM chat_threads WHERE thread_id IN (:thread_ids)
             )
           ) AS recent_messages
           WHERE recent_messages.row_number = 1
         )
         UPDATE user_chat_thread_memberships
         SET last_read_message_id = cte.id
         FROM cte
         WHERE user_chat_thread_memberships.last_read_message_id IN (:last_read_message_ids)
         AND cte.thread_id = user_chat_thread_memberships.thread_id;

          -- then reset all last_read_message_ids to null
          -- for the cases where all messages in the thread were
          -- already deleted
          UPDATE user_chat_thread_memberships
          SET last_read_message_id = NULL
          WHERE last_read_message_id IN (:last_read_message_ids);
        SQL
      end
    end
  end
end
