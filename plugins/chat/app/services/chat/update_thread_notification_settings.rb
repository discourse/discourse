# frozen_string_literal: true

module Chat
  # Updates the thread notification level for a user, or if the thread
  # does not exist, adds the user as a member of the thread before setting
  # the notification level.
  #
  # @example
  # Chat::UpdateThreadNotificationSettings.call(
  #   thread_id: 88,
  #   channel_id: 2,
  #   guardian: guardian,
  #   notification_level: notification_level,
  # )
  #
  class UpdateThreadNotificationSettings
    include Service::Base

    # @!method call(thread_id:, channel_id:, guardian:, notification_level:)
    #   @param [Integer] thread_id
    #   @param [Integer] channel_id
    #   @param [Integer] notification_level
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
      attribute :notification_level, :integer

      validates :thread_id, :channel_id, :notification_level, presence: true

      validates :notification_level,
                inclusion: {
                  in: Chat::UserChatThreadMembership.notification_levels.values,
                }
    end

    private

    def fetch_thread(contract:, **)
      Chat::Thread.find_by(id: contract.thread_id, channel_id: contract.channel_id)
    end

    def can_view_channel(guardian:, thread:, **)
      guardian.can_preview_chat_channel?(thread.channel)
    end

    def threading_enabled_for_channel(thread:, **)
      thread.channel.threading_enabled
    end

    def create_or_update_membership(thread:, guardian:, contract:, **)
      membership = thread.membership_for(guardian.user)
      if !membership
        membership = thread.add(guardian.user)
        membership.update!(last_read_message_id: thread.last_message_id)
      end
      membership.update!(notification_level: contract.notification_level)
      context.membership = membership
    end
  end
end
