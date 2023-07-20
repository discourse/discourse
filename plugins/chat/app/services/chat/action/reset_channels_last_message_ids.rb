# frozen_string_literal: true

module Chat
  module Action
    class ResetChannelsLastMessageIds
      # @param [Array] last_message_ids The message IDs to match with the
      #   last_message_id in Chat::Channel which will be reset
      #   to NULL or the most recent non-deleted message in the channel to
      #   update read state.
      # @param [Integer] channel_ids The channel IDs to update. This is used
      #   to scope the queries better.
      def self.call(last_message_ids, channel_ids)
        Chat::Channel
          .where(id: channel_ids)
          .where("last_message_id IN (?)", last_message_ids)
          .find_in_batches { |channels| channels.each(&:update_last_message_id!) }
      end
    end
  end
end
