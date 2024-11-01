# frozen_string_literal: true

module Chat
  # Service responsible for stopping streaming of a message.
  #
  # @example
  #  Chat::StopMessageStreaming.call(params: { message_id: 3 }, guardian: guardian)
  #
  class StopMessageStreaming
    include ::Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :message_id
    #   @return [Service::Base::Context]
    params do
      attribute :message_id, :integer

      validates :message_id, presence: true
    end
    model :message
    step :enforce_membership
    model :membership
    policy :can_stop_streaming
    step :stop_message_streaming
    step :publish_message_streaming_state
    step :leave_chat_reply_presence_channel

    private

    def fetch_message(params:)
      ::Chat::Message.find_by(id: params.message_id)
    end

    def enforce_membership(guardian:, message:)
      message.chat_channel.add(guardian.user) if guardian.user.bot?
    end

    def fetch_membership(guardian:, message:)
      message.chat_channel.membership_for(guardian.user)
    end

    def can_stop_streaming(guardian:, message:)
      guardian.user.bot? || guardian.is_admin? || message.user.id == guardian.user.id ||
        message.in_reply_to && message.in_reply_to.user_id == guardian.user.id
    end

    def stop_message_streaming(message:)
      message.update!(streaming: false)
    end

    def publish_message_streaming_state(guardian:, message:)
      ::Chat::Publisher.publish_edit!(message.chat_channel, message)
    end

    def leave_chat_reply_presence_channel(message:)
      presence_channel = PresenceChannel.new(message.presence_channel_name)
      presence_channel.leave(user_id: message.user_id, client_id: message.id)
    end
  end
end
