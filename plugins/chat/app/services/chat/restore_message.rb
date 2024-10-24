# frozen_string_literal: true

module Chat
  # Service responsible for restoring a trashed chat message
  # for a channel and ensuring that the client and read state is
  # updated.
  #
  # @example
  #  Chat::RestoreMessage.call(params: { message_id: 2, channel_id: 1 }, guardian: guardian)
  #
  class RestoreMessage
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :message_id
    #   @option params [Integer] :channel_id
    #   @return [Service::Base::Context]

    params do
      attribute :message_id, :integer
      attribute :channel_id, :integer

      validates :message_id, presence: true
      validates :channel_id, presence: true
    end
    model :message
    policy :invalid_access
    transaction do
      step :restore_message
      step :update_last_message_ids
      step :update_thread_reply_cache
    end
    step :publish_events

    private

    def fetch_message(params:)
      Chat::Message
        .with_deleted
        .includes(chat_channel: :chatable)
        .find_by(id: params[:message_id], chat_channel_id: params[:channel_id])
    end

    def invalid_access(guardian:, message:)
      guardian.can_restore_chat?(message, message.chat_channel.chatable)
    end

    def restore_message(message:)
      message.recover!
    end

    def update_thread_reply_cache(message:)
      message.thread&.increment_replies_count_cache
    end

    def update_last_message_ids(message:)
      message.thread&.update_last_message_id!
      message.chat_channel.update_last_message_id!
    end

    def publish_events(guardian:, message:)
      DiscourseEvent.trigger(:chat_message_restored, message, message.chat_channel, guardian.user)
      Chat::Publisher.publish_restore!(message.chat_channel, message)

      if message.thread.present?
        Chat::Publisher.publish_thread_original_message_metadata!(message.thread)
      end
    end
  end
end
