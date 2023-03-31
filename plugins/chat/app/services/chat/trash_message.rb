# frozen_string_literal: true

module Chat
  # Service responsible for trashing a chat message
  # and ensuring that the client and read state is
  # updated.
  #
  # @example
  #  Chat::TrashMessage.call(message_id: 2, guardian: guardian)
  #
  class TrashMessage
    include Service::Base

    # @!method call(message_id:, guardian:)
    #   @param [Integer] message_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    model :message
    policy :invalid_access
    transaction do
      step :trash_message
      step :destroy_mentions
      step :update_tracking_state
    end
    step :publish_events

    # @!visibility private
    class Contract
      attribute :message_id, :integer
      validates :message_id, presence: true
    end

    private

    def fetch_message(contract:, **)
      Chat::Message.includes(chat_channel: :chatable).find_by(id: contract.message_id)
    end

    def invalid_access(guardian:, message:, **)
      guardian.can_delete_chat?(message, message.chat_channel.chatable)
    end

    def trash_message(message:, **)
      message.trash!
    end

    def destroy_mentions(message:, **)
      Chat::Mention.where(chat_message: message).destroy_all
    end

    def update_tracking_state(message:, **)
      Chat::UserChatChannelMembership.where(last_read_message_id: message.id).update_all(
        last_read_message_id: nil,
      )
    end

    def publish_events(guardian:, message:, **)
      DiscourseEvent.trigger(:chat_message_trashed, message, message.chat_channel, guardian.user)
      Chat::Publisher.publish_delete!(message.chat_channel, message)
    end
  end
end
