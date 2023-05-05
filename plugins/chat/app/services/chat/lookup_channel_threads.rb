# frozen_string_literal: true

module Chat
  # Gets a list of threads for a channel to be shown in an index.
  # In future pagination and filtering will be added -- for now
  # we just want to return N threads by X order.
  #
  # @example
  #  Chat::LookupChannelThreads.call(channel_id: 2, guardian: guardian)
  #
  class LookupChannelThreads
    include Service::Base

    # @!method call(channel_id:, guardian:)
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    policy :threaded_discussions_enabled
    contract
    model :channel
    policy :threading_enabled_for_channel
    policy :can_view_channel
    model :threads

    # @!visibility private
    class Contract
      attribute :channel_id, :integer
      validates :channel_id, presence: true
    end

    private

    def threaded_discussions_enabled
      SiteSetting.enable_experimental_chat_threaded_discussions
    end

    def fetch_channel(contract:, **)
      Chat::Channel.find_by(id: contract.channel_id)
    end

    def threading_enabled_for_channel(channel:, **)
      channel.threading_enabled
    end

    def can_view_channel(guardian:, channel:, **)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_threads(guardian:, channel:, **)
      Chat::Thread
        .includes(
          :channel,
          original_message_user: :user_status,
          original_message: :chat_webhook_event,
        )
        .select("chat_threads.*, MAX(chat_messages.created_at) AS last_posted_at")
        .joins("LEFT JOIN chat_messages ON chat_threads.id = chat_messages.thread_id")
        .joins(
          "LEFT JOIN chat_messages original_messages ON chat_threads.original_message_id = original_messages.id",
        )
        .where("chat_messages.user_id = ? OR chat_messages.user_id IS NULL", guardian.user.id)
        .where(channel_id: channel.id)
        .where("original_messages.deleted_at IS NULL")
        .group("chat_threads.id")
        .order("last_posted_at DESC NULLS LAST")
        .limit(50)
    end
  end
end
