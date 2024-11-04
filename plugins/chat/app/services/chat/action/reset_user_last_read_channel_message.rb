# frozen_string_literal: true

module Chat
  module Action
    class ResetUserLastReadChannelMessage < Service::ActionBase
      # @param [Array] last_read_message_ids The message IDs to match with the
      #   last_read_message_ids in UserChatChannelMembership which will be reset
      #   to NULL or the most recent non-deleted message in the channel to
      #   update read state.
      # @param [Integer] channel_ids The channel IDs of the memberships to update,
      #   this is used to find the latest non-deleted message in the channel.
      param :last_read_message_ids, []
      param :channel_ids, []

      def call
        DB.exec(sql_query, last_read_message_ids:, channel_ids:)
      end

      private

      def sql_query
        <<~SQL
         -- update the last_read_message_id to the most recent
         -- non-deleted message in the channel so unread counts are correct.
         -- the cte row_number is necessary to only return a single row
         -- for each channel to prevent additional data being returned
         WITH cte AS (
           SELECT chat_channels.id AS chat_channel_id, last_message_id
           FROM chat_channels
           WHERE chat_channels.id IN (:channel_ids)
         )
         UPDATE user_chat_channel_memberships
         SET last_read_message_id = cte.last_message_id
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
      end
    end
  end
end
