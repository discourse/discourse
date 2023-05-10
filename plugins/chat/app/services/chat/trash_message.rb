# frozen_string_literal: true

module Chat
  # Service responsible for trashing a chat message
  # for a channel and ensuring that the client and read state is
  # updated.
  #
  # @example
  #  Chat::TrashMessage.call(message_id: 2, channel_id: 1, guardian: guardian)
  #
  class TrashMessage
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
      step :trash_message
      step :destroy_mentions
      step :update_tracking_state
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
      Chat::Message.includes(chat_channel: :chatable).find_by(
        id: contract.message_id,
        chat_channel_id: contract.channel_id,
      )
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
      ::Chat::Action::ResetUserLastReadChannelMessage.call([message.id], [message.chat_channel_id])
    end

    def update_thread_reply_cache(message:, **)
      message.thread&.decrement_replies_count_cache
    end

    def publish_events(guardian:, message:, **)
      DiscourseEvent.trigger(:chat_message_trashed, message, message.chat_channel, guardian.user)
      Chat::Publisher.publish_delete!(message.chat_channel, message)
    end
  end
end
