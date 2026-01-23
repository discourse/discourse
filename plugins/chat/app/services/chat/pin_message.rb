# frozen_string_literal: true

module Chat
  class PinMessage
    include Service::Base

    params do
      attribute :message_id, :integer
      attribute :channel_id, :integer

      validates :message_id, presence: true
      validates :channel_id, presence: true
    end

    model :message
    policy :can_pin
    policy :within_pin_limit
    policy :not_already_pinned

    transaction { step :create_pin }

    step :post_system_message
    step :publish_pin_event

    private

    def fetch_message(params:)
      Chat::Message.includes(:chat_channel).find_by(
        id: params.message_id,
        chat_channel_id: params.channel_id,
      )
    end

    def can_pin(guardian:, message:)
      guardian.can_pin_chat_message?(message)
    end

    def within_pin_limit(message:)
      message.chat_channel.pinned_messages.count < Chat::PinnedMessage::MAX_PINS_PER_CHANNEL
    end

    def not_already_pinned(message:)
      !message.pinned_message.present?
    end

    def create_pin(message:, guardian:)
      context[:pin] = Chat::PinnedMessage.create!(
        chat_message: message,
        chat_channel: message.chat_channel,
        pinned_by_id: guardian.user.id,
      )
    end

    def post_system_message(message:, guardian:)
      Chat::CreateMessage.call(
        guardian: Discourse.system_user.guardian,
        params: {
          chat_channel_id: message.chat_channel_id,
          message:
            I18n.t(
              "chat.channel.message_pinned",
              username: "@#{guardian.user.username}",
              message_url: message.url,
              count: 1,
            ),
        },
      )
    end

    def publish_pin_event(message:, pin:)
      Chat::Publisher.publish_pin!(message.chat_channel, message, pin)
    end
  end
end
