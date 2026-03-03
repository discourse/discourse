# frozen_string_literal: true

module Chat
  # Service responsible for rebaking a chat message.
  #
  # @example
  #  Chat::RebakeMessage.call(params: { message_id: 2, chat_channel_id: 1 }, guardian: guardian)
  #
  class RebakeMessage
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :message_id
    #   @option params [Integer] :chat_channel_id
    #   @return [Service::Base::Context]

    params do
      attribute :message_id, :integer
      attribute :chat_channel_id, :integer

      validates :message_id, presence: true
      validates :chat_channel_id, presence: true
    end

    model :channel
    policy :can_access_channel
    model :message
    policy :can_rebake

    step :rebake_message

    private

    def fetch_channel(params:)
      Chat::Channel.includes(:chatable).find_by(id: params.chat_channel_id)
    end

    def can_access_channel(guardian:, channel:)
      guardian.can_join_chat_channel?(channel)
    end

    def fetch_message(params:, channel:)
      Chat::Message
        .includes(chat_channel: :chatable)
        .with_deleted
        .find_by(id: params.message_id, chat_channel_id: channel.id)
    end

    def can_rebake(guardian:, message:)
      guardian.can_rebake_chat_message?(message)
    end

    def rebake_message(message:)
      message.rebake!(invalidate_oneboxes: true)
    end
  end
end
