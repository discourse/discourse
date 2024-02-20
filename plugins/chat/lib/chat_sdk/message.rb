# frozen_string_literal: true

module ChatSDK
  class Message
    include Chat::WithServiceHelper

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
    # @return [ChMessage] The created message object.
    #
    # @example Creating a simple message
    #   ChatSDK::Message.create(raw: "Hello, world!", channel_id: 1, guardian: Guardian.new)
    #
    # @example Creating a message with a block for streaming
    #   Message.create_with_stream(raw: "Streaming message", channel_id: 1, guardian: Guardian.new) do |helper, message|
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
      self.create(**params, streaming: true, &block)
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
      &block
    )
      message =
        with_service(
          Chat::CreateMessage,
          message: raw,
          guardian: guardian,
          chat_channel_id: channel_id,
          in_reply_to_id: in_reply_to_id,
          thread_id: thread_id,
          upload_ids: upload_ids,
          streaming: streaming,
          enforce_membership: enforce_membership,
        ) do
          on_model_not_found(:channel) { raise "Couldn't find channel with id: `#{channel_id}`" }
          on_model_not_found(:channel_membership) do
            raise "User with id: `#{guardian.user.id}` has no membership to this channel"
          end
          on_failed_policy(:ensure_valid_thread_for_channel) do
            raise "Couldn't find thread with id: `#{thread_id}`"
          end
          on_failed_policy(:allowed_to_join_channel) do
            raise "User with id: `#{guardian.user.id}` can't join this channel"
          end
          on_failed_contract { |contract| raise contract.errors.full_messages.join(", ") }
          on_success { result.message_instance }
          on_failure do
            p Chat::StepsInspector.new(result)
            raise "Unexpected error"
          end
        end

      if streaming && block_given?
        helper = Helper.new(message)
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

  class Helper
    include Chat::WithServiceHelper

    attr_reader :message

    def initialize(message)
      @message = message
    end

    def stream(raw: nil)
      return false unless self.message.reload.streaming

      with_service(
        Chat::UpdateMessage,
        message_id: self.message.id,
        message: raw ? self.message.reload.message + " " + raw : self.message.message,
        guardian: self.message.user.guardian,
        streaming: true,
      ) do
        on_failure do
          p Chat::StepsInspector.new(result)
          raise "Unexpected error"
        end
      end

      self.message
    end
  end
end
