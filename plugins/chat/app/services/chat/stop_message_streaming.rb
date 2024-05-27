# frozen_string_literal: true

module Chat
  # Service responsible for stopping streaming of a message.
  #
  # @example
  #  Chat::StopMessageStreaming.call(message_id: 3, guardian: guardian)
  #
  class StopMessageStreaming
    include ::Service::Base

    # @!method call(message_id:, guardian:)
    #   @param [Integer] message_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]
    contract
    model :message
    step :enforce_membership
    model :membership
    policy :can_stop_streaming
    step :stop_message_streaming
    step :publish_message_streaming_state

    # @!visibility private
    class Contract
      attribute :message_id, :integer

      validates :message_id, presence: true
    end

    private

    def fetch_message(contract:)
      ::Chat::Message.find_by(id: contract.message_id)
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

    def publish_message_streaming_state(guardian:, message:, contract:)
      ::Chat::Publisher.publish_edit!(message.chat_channel, message)
    end
  end
end
