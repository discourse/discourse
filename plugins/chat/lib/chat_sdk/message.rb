# frozen_string_literal: true

module ChatSDK
  class Message
    # Creates a new message in a chat channel.
    #
    # @param raw [String] The content of the message.
    # @param channel_id [Integer] The ID of the chat channel.
    # @param guardian [Guardian] The user's guardian object, for policy enforcement.
    # @param in_reply_to_id [Integer, nil] The ID of the message this is in reply to (optional).
    # @param thread_id [Integer, nil] The ID of the thread this message belongs to (optional).
    # @param upload_ids [Array<Integer>, nil] The IDs of any uploads associated with the message (optional).
    # @param streaming [Boolean] Whether the message is part of a streaming operation (default: false).
    # @param enforce_membership [Boolean] Allows to ensure the guardian will be allowed in the channel (default: false).
    # @yield [helper, message] Offers a block with a helper and the message for streaming operations.
    # @yieldparam helper [Helper] The helper object for streaming operations.
    # @yieldparam message [Message] The newly created message object.
    # @return [Chat::Message] The created message object.
    #
    # @example Creating a simple message
    #   ChatSDK::Message.create(raw: "Hello, world!", channel_id: 1, guardian: Guardian.new)
    #
    # @example Creating a message with a block for streaming
    #   ChatSDK::Message.create_with_stream(raw: "Streaming message", channel_id: 1, guardian: Guardian.new) do |helper, message|
    #     helper.stream(raw: "Continuation of the message")
    #   end
    def self.create(**params, &block)
      new.create(**params, &block)
    end

    # Creates a new message with streaming enabled by default.
    #
    # This method is a convenience wrapper around `create` with `streaming: true` set by default.
    # It supports all the same parameters and block usage as `create`.
    #
    # @see #create
    def self.create_with_stream(**params, &block)
      self.create(**params, streaming: true, strip_whitespaces: false, &block)
    end

    # Streams to a specific chat message.
    #
    # @param raw [String] text to append to the existing message.
    # @param message_id [Integer] the ID of the message to stream.
    # @param guardian [Guardian] an instance of the guardian class, representing the user's permissions.
    # @return [Chat::Message] The message object.
    # @example Streaming a message
    #   ChatSDK::Message.stream(message_id: 42, guardian: guardian, raw: "text")
    def self.stream(raw:, message_id:, guardian:, &block)
      new.stream(raw: raw, message_id: message_id, guardian: guardian, &block)
    end

    # Starts streaming for a specific chat message.
    #
    # @param message_id [Integer] the ID of the message for which streaming should be stopped.
    # @param guardian [Guardian] an instance of the guardian class, representing the user's permissions.
    # @return [Chat::Message] The message object.
    # @example Starting the streaming of a message
    #   ChatSDK::Message.start_stream(message_id: 42, guardian: guardian)
    def self.start_stream(message_id:, guardian:)
      new.start_stream(message_id: message_id, guardian: guardian)
    end

    # Stops streaming for a specific chat message.
    #
    # @param message_id [Integer] the ID of the message for which streaming should be stopped.
    # @param guardian [Guardian] an instance of the guardian class, representing the user's permissions.
    # @return [Chat::Message] The message object.
    # @example Stopping the streaming of a message
    #   ChatSDK::Message.stop_stream(message_id: 42, guardian: guardian)
    def self.stop_stream(message_id:, guardian:)
      new.stop_stream(message_id: message_id, guardian: guardian)
    end

    def start_stream(message_id:, guardian:)
      message = Chat::Message.find(message_id)
      guardian.ensure_can_edit_chat!(message)
      message.update!(streaming: true)
      ::Chat::Publisher.publish_edit!(message.chat_channel, message.reload)
      message
    end

    def stream(message_id:, raw:, guardian:, &block)
      message = Chat::Message.find(message_id)
      helper = StreamHelper.new(message, guardian)
      helper.stream(raw: raw)
      ::Chat::Publisher.publish_edit!(message.chat_channel, message.reload)
      message
    end

    def stop_stream(message_id:, guardian:)
      Chat::StopMessageStreaming.call(message_id:, guardian:) do
        on_success { result.message }
        on_model_not_found(:message) { raise "Couldn't find message with id: `#{message_id}`" }
        on_model_not_found(:membership) do
          raise "Couldn't find membership for user with id: `#{guardian.user.id}`"
        end
        on_failed_policy(:can_join_channel) do
          raise "User with id: `#{guardian.user.id}` can't join this channel"
        end
        on_failed_policy(:can_stop_streaming) do
          raise "User with id: `#{guardian.user.id}` can't stop streaming this message"
        end
        on_failure { raise "Unexpected error" }
      end
    end

    def create(
      raw:,
      channel_id:,
      guardian:,
      in_reply_to_id: nil,
      thread_id: nil,
      upload_ids: nil,
      streaming: false,
      enforce_membership: false,
      force_thread: false,
      strip_whitespaces: true,
      **params,
      &block
    )
      message =
        Chat::CreateMessage.call(
          message: raw,
          guardian: guardian,
          chat_channel_id: channel_id,
          in_reply_to_id: in_reply_to_id,
          thread_id: thread_id,
          upload_ids: upload_ids,
          streaming: streaming,
          enforce_membership: enforce_membership,
          force_thread: force_thread,
          strip_whitespaces: strip_whitespaces,
          created_by_sdk: true,
          **params,
        ) do
          on_model_not_found(:channel) { raise "Couldn't find channel with id: `#{channel_id}`" }
          on_model_not_found(:membership) do
            raise "Couldn't find membership for user with id: `#{guardian.user.id}`"
          end
          on_failed_policy(:ensure_valid_thread_for_channel) do
            raise "Couldn't find thread with id: `#{thread_id}`"
          end
          on_failed_policy(:allowed_to_join_channel) do
            raise "User with id: `#{guardian.user.id}` can't join this channel"
          end
          on_failed_contract { |contract| raise contract.errors.full_messages.join(", ") }
          on_success { result.message_instance }
          on_failure { raise "Unexpected error" }
        end

      if streaming && block_given?
        helper = StreamHelper.new(message, guardian)
        block.call(helper, message)
      end

      message
    ensure
      if message && streaming
        message.update!(streaming: false)
        ::Chat::Publisher.publish_edit!(message.chat_channel, message.reload)
      end
    end
  end

  class StreamHelper
    attr_reader :message
    attr_reader :guardian

    def initialize(message, guardian)
      @message = message.reload
      @guardian = guardian
    end

    def stream(raw: nil)
      return false if !message.streaming || !raw

      Chat::UpdateMessage.call(
        message_id: message.id,
        message: message.message + raw,
        guardian: guardian,
        streaming: true,
        strip_whitespaces: false,
      ) { on_failure { raise "Unexpected error" } }

      message
    end
  end
end
