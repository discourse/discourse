# frozen_string_literal: true

module Chat
  # Finds a thread within a channel. The thread_id and channel_id must
  # match. For now we do not want to allow fetching threads if the
  # enable_experimental_chat_threaded_discussions hidden site setting
  # is not turned on, and the channel must specifically have threading
  # enabled.
  #
  # @example
  #  Chat::LookupThread.call(thread_id: 88, channel_id: 2, guardian: guardian)
  #
  class LookupThread
    include Service::Base

    # @!method call(thread_id:, channel_id:, guardian:)
    #   @param [Integer] thread_id
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    policy :threaded_discussions_enabled
    contract
    model :thread, :fetch_thread
    policy :invalid_access
    policy :threading_enabled_for_channel

    # @!visibility private
    class Contract
      attribute :thread_id, :integer
      attribute :channel_id, :integer

      validates :thread_id, :channel_id, presence: true
    end

    private

    def threaded_discussions_enabled
      SiteSetting.enable_experimental_chat_threaded_discussions
    end

    def fetch_thread(contract:, **)
      Chat::Thread.includes(
        :channel,
        original_message_user: :user_status,
        original_message: :chat_webhook_event,
      ).find_by(id: contract.thread_id, channel_id: contract.channel_id)
    end

    def invalid_access(guardian:, thread:, **)
      guardian.can_preview_chat_channel?(thread.channel)
    end

    def threading_enabled_for_channel(thread:, **)
      thread.channel.threading_enabled
    end
  end
end
