# frozen_string_literal: true

module Chat
  # Service responsible for trashing multiple chat messages.
  #
  # @example
  #  Chat::TrashMessages.call(message_ids: [2, 3], channel_id: 1, guardian: guardian)
  #
  class TrashMessages
    include Service::Base

    # @!method call(message_ids:, channel_id:, guardian:)
    #   @param [Array<Integer>] message_ids
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    model :messages
    step :trash_messages
    step :publish_events

    # @!visibility private
    class Contract
      attribute :channel_id, :integer
      attribute :message_ids, :array
      validates :channel_id, presence: true
      validates :message_ids, length: { minimum: 1, maximum: 50 }
    end

    private

    def fetch_messages(contract:)
      Chat::Message.includes(chat_channel: :chatable).where(
        id: contract.message_ids,
        chat_channel_id: contract.channel_id,
      )
    end

    def trash_messages(contract:, guardian:, messages:)
      messages.each do |message|
        Chat::TrashMessage.call(
          message_id: message.id,
          channel_id: contract.channel_id,
          guardian: guardian,
          skip_publish: true,
        )
      end
    end

    def publish_events(contract:, guardian:, messages:)
      Chat::Publisher.publish_bulk_delete!(messages.first.chat_channel, contract.message_ids)
    end
  end
end
