# frozen_string_literal: true

module Chat
  class UnpinMessage
    include Service::Base

    params do
      attribute :message_id, :integer
      attribute :channel_id, :integer

      validates :message_id, presence: true
      validates :channel_id, presence: true
    end

    model :message
    policy :can_unpin
    model :pin

    transaction { step :destroy_pin }

    step :post_system_message
    step :publish_unpin_event

    private

    def fetch_message(params:)
      Chat::Message.includes(:chat_channel).find_by(
        id: params.message_id,
        chat_channel_id: params.channel_id,
      )
    end

    def can_unpin(guardian:, message:)
      guardian.can_unpin_chat_message?(message)
    end

    def fetch_pin(message:)
      message.pinned_message
    end

    def destroy_pin(pin:)
      pin.destroy!
    end

    def post_system_message(message:, guardian:)
      Chat::CreateMessage.call(
        guardian: Discourse.system_user.guardian,
        params: {
          chat_channel_id: message.chat_channel_id,
          message:
            I18n.t(
              "chat.channel.message_unpinned",
              username: guardian.user.username,
              message_url: message.url,
              count: 1,
            ),
        },
      )
    end

    def publish_unpin_event(message:)
      Chat::Publisher.publish_unpin!(message.chat_channel, message)
    end
  end
end
