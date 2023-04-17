# frozen_string_literal: true

module Chat
  # Service responsible for restoreing a trashed chat message
  # for a channel and ensuring that the client and read state is
  # updated.
  #
  # @example
  #  Chat::RestoreMessage.call(message_id: 2, channel_id: 1, guardian: guardian)
  #
  class RestoreMessage
    include Service::Base

    # @!method call(message_id:, channel_id:, guardian:)
    #   @param [Integer] message_id
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    model :message
    policy :invalid_access
    transaction do
      step :restore_message
      step :update_thread_reply_cache
    end
    step :publish_events

    # @!visibility private
    class Contract
      attribute :message_id, :integer
      attribute :channel_id, :integer
      validates :message_id, presence: true
      validates :channel_id, presence: true
    end

    private

    def fetch_message(contract:, **)
      Chat::Message
        .with_deleted
        .includes(chat_channel: :chatable)
        .find_by(id: contract.message_id, chat_channel_id: contract.channel_id)
    end

    def invalid_access(guardian:, message:, **)
      guardian.can_restore_chat?(message, message.chat_channel.chatable)
    end

    def restore_message(message:, **)
      message.recover!
    end

    def update_thread_reply_cache(message:, **)
      message.thread&.increment_replies_count_cache
    end

    def publish_events(guardian:, message:, **)
      DiscourseEvent.trigger(:chat_message_restored, message, message.chat_channel, guardian.user)
      Chat::Publisher.publish_restore!(message.chat_channel, message)
    end
  end
end
