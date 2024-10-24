# frozen_string_literal: true

module Chat
  # Marks the thread title prompt as seen for a specific user/thread
  # Note: if the thread does not exist, it adds the user as a member of the thread
  # before setting the thread title prompt.
  #
  # @example
  # Chat::MarkThreadTitlePromptSeen.call(
  #   params: {
  #     thread_id: 88,
  #     channel_id: 2,
  #   },
  #   guardian: guardian,
  # )
  #
  class MarkThreadTitlePromptSeen
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :thread_id
    #   @option params [Integer] :channel_id
    #   @return [Service::Base::Context]

    contract do
      attribute :thread_id, :integer
      attribute :channel_id, :integer

      validates :thread_id, :channel_id, presence: true
    end
    model :thread
    policy :threading_enabled_for_channel
    policy :can_view_channel
    transaction { step :create_or_update_membership }

    private

    def fetch_thread(contract:)
      Chat::Thread.find_by(id: contract.thread_id, channel_id: contract.channel_id)
    end

    def can_view_channel(guardian:, thread:)
      guardian.can_preview_chat_channel?(thread.channel)
    end

    def threading_enabled_for_channel(thread:)
      thread.channel.threading_enabled
    end

    def create_or_update_membership(thread:, guardian:, contract:)
      membership = thread.membership_for(guardian.user)
      membership =
        thread.add(
          guardian.user,
          notification_level: Chat::NotificationLevels.all[:normal],
        ) if !membership
      membership.update!(thread_title_prompt_seen: true)
      context[:membership] = membership
    end
  end
end
