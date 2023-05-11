# frozen_string_literal: true

module Chat
  module Action
    class ResetUserLastReadChannelMessage
      # @param [Array] last_read_message_ids The message IDs to match with the
      #   last_read_message_ids in UserChatChannelMembership which will be reset
      #   to NULL or the most recent non-deleted message in the channel to
      #   update read state.
      # @param [Integer] channel_ids The channel IDs of the memberships to update,
      #   this is used to find the latest non-deleted message in the channel.
      def self.call(last_read_message_ids, channel_ids)
        sql = <<~SQL
         -- update the last_read_message_id to the most recent
         -- non-deleted message in the channel so unread counts are correct.
         -- the cte row_number is necessary to only return a single row
         -- for each channel to prevent additional data being returned
         WITH cte AS (
           SELECT * FROM (
             SELECT id, chat_channel_id, row_number() OVER (
                 PARTITION BY chat_channel_id ORDER BY created_at DESC, id DESC
               ) AS row_number
             FROM chat_messages
             WHERE deleted_at IS NULL AND chat_channel_id IN (:channel_ids)
           ) AS recent_messages
           WHERE recent_messages.row_number = 1
         )
         UPDATE user_chat_channel_memberships
         SET last_read_message_id = cte.id
         FROM cte
         WHERE user_chat_channel_memberships.last_read_message_id IN (:last_read_message_ids)
         AND cte.chat_channel_id = user_chat_channel_memberships.chat_channel_id;

          -- then reset all last_read_message_ids to null
          -- for the cases where all messages in the channel were
          -- already deleted
          UPDATE user_chat_channel_memberships
          SET last_read_message_id = NULL
          WHERE last_read_message_id IN (:last_read_message_ids);
        SQL

        DB.exec(sql, last_read_message_ids: last_read_message_ids, channel_ids: channel_ids)
      end
    end
  end
end
