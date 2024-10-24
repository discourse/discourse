# frozen_string_literal: true

module ChatSDK
  class Channel
    # Retrieves messages from a specified channel.
    #
    # @param channel_id [Integer] The ID of the chat channel from which to fetch messages.
    # @param guardian [Guardian] The guardian object representing the user's permissions.
    # @return [Array<ChMessage>] An array of message objects from the specified channel.
    #
    # @example Fetching messages from a channel with additional parameters
    #   ChatSDK::Channel.messages(channel_id: 1, guardian: Guardian.new)
    #
    def self.messages(...)
      new.messages(...)
    end

    def messages(channel_id:, guardian:, **params)
      Chat::ListChannelMessages.call(
        guardian:,
        params: {
          channel_id:,
          direction: "future",
          **params,
        },
      ) do
        on_success { |messages:| messages }
        on_failure { raise "Unexpected error" }
        on_failed_policy(:can_view_channel) { raise "Guardian can't view channel" }
        on_failed_policy(:target_message_exists) { raise "Target message doesn't exist" }
      end
    end
  end
end
