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
    # @raise [RuntimeError] Raises an "Unexpected error" if the message retrieval fails for an unspecified reason.
    # @raise [RuntimeError] Raises "Guardian can't view channel" if the user's permissions are insufficient to view the channel.
    # @raise [RuntimeError] Raises "Target message doesn't exist" if the specified target message cannot be found in the channel.
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

    # Initiates a reply in a specified channel or thread.
    #
    # @param channel_id [Integer] The ID of the channel where the reply is started.
    # @param thread_id [Integer, nil] (optional) The ID of the thread within the channel where the reply is started.
    # @param guardian [Guardian] The guardian object representing the user's permissions.
    # @return [String] The client ID associated with the initiated reply.
    #
    # @example Starting a reply in a channel
    #   ChatSDK::Channel.start_reply(channel_id: 1, guardian: Guardian.new)
    #
    # @example Starting a reply in a specific thread
    #   ChatSDK::Channel.start_reply(channel_id: 1, thread_id: 34, guardian: Guardian.new)
    #
    # @raise [RuntimeError] Raises an error if the specified channel or thread is not found.
    def self.start_reply(...)
      new.start_reply(...)
    end

    def start_reply(channel_id:, thread_id: nil, guardian:)
      Chat::StartReply.call(
        guardian: guardian,
        params: {
          channel_id: channel_id,
          thread_id: thread_id,
        },
      ) do
        on_success { |client_id:| client_id }
        on_model_not_found(:presence_channel) { raise "Chat::Channel or Chat::Thread not found." }
      end
    end

    # Ends an ongoing reply in a specified channel or thread.
    #
    # @param channel_id [Integer] The ID of the channel where the reply is being stopped.
    # @param thread_id [Integer, nil] (optional) The ID of the thread within the channel where the reply is being stopped.
    # @param client_id [String] The client ID associated with the reply to stop.
    # @param guardian [Guardian] The guardian object representing the user's permissions.
    #
    # @example Stopping a reply in a channel
    #   ChatSDK::Channel.stop_reply(channel_id: 1, client_id: "abc123", guardian: Guardian.new)
    #
    # @example Stopping a reply in a specific thread
    #   ChatSDK::Channel.stop_reply(channel_id: 1, thread_id: 34, client_id: "abc123", guardian: Guardian.new)
    #
    # @raise [RuntimeError] Raises an error if the specified channel or thread is not found.
    def self.stop_reply(...)
      new.stop_reply(...)
    end

    def stop_reply(channel_id:, thread_id: nil, client_id:, guardian:)
      Chat::StopReply.call(
        guardian: guardian,
        params: {
          client_id: client_id,
          channel_id: channel_id,
          thread_id: thread_id,
        },
      ) do
        on_model_not_found(:presence_channel) { raise "Chat::Channel or Chat::Thread not found." }
      end
    end
  end
end
