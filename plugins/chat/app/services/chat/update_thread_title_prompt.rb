# frozen_string_literal: true

module Chat
  # Updates the thread title prompt for a user, or if the thread
  # does not exist, adds the user as a member of the thread before setting
  # the thread title prompt.
  #
  # @example
  # Chat::UpdateThreadTitlePrompt.call(
  #   thread_id: 88,
  #   channel_id: 2,
  #   guardian: guardian,
  #   thread_title_prompt_seen: true,
  # )
  #
  class UpdateThreadTitlePrompt
    include Service::Base

    # @!method call(thread_id:, channel_id:, guardian:, thread_title_prompt_seen:)
    #   @param [Integer] thread_id
    #   @param [Integer] channel_id
    #   @param [Boolean] thread_title_prompt_seen
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    model :thread, :fetch_thread
    policy :can_view_channel
    policy :threading_enabled_for_channel
    transaction { step :create_or_update_membership }

    # @!visibility private
    class Contract
      attribute :thread_id, :integer
      attribute :channel_id, :integer
      attribute :thread_title_prompt_seen, :boolean

      validates :thread_id, :channel_id, :thread_title_prompt, presence: true

      validates :thread_title_prompt_seen, inclusion: { in: [true, false] }
    end

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
      membership = thread.add(guardian.user) if !membership
      membership.update!(thread_title_prompt_seen: contract.thread_title_prompt_seen)
      context.membership = membership
    end
  end
end
