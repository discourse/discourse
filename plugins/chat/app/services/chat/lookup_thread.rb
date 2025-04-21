# frozen_string_literal: true

module Chat
  # Finds a thread within a channel. The thread_id and channel_id must
  # match, and the channel must specifically have threading enabled.
  #
  # @example
  #  Chat::LookupThread.call(params: { thread_id: 88, channel_id: 2 }, guardian: guardian)
  #
  class LookupThread
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :thread_id
    #   @option params [Integer] :channel_id
    #   @return [Service::Base::Context]

    params do
      attribute :thread_id, :integer
      attribute :channel_id, :integer

      validates :thread_id, :channel_id, presence: true
    end

    model :thread
    policy :invalid_access
    policy :threading_enabled_for_channel
    model :membership, optional: true
    model :participants, optional: true

    private

    def fetch_thread(params:)
      Chat::Thread.includes(
        :channel,
        original_message_user: :user_status,
        original_message: :chat_webhook_event,
      ).find_by(id: params.thread_id, channel_id: params.channel_id)
    end

    def invalid_access(guardian:, thread:)
      guardian.can_preview_chat_channel?(thread.channel)
    end

    def threading_enabled_for_channel(thread:)
      thread.channel.threading_enabled || thread.force
    end

    def fetch_membership(thread:, guardian:)
      thread.membership_for(guardian.user)
    end

    def fetch_participants(thread:)
      ::Chat::ThreadParticipantQuery.call(thread_ids: [thread.id])[thread.id]
    end
  end
end
