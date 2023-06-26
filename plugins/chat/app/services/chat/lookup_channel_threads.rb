# frozen_string_literal: true

module Chat
  # Gets a list of threads for a channel to be shown in an index.
  # In future pagination and filtering will be added -- for now
  # we just want to return N threads ordered by the latest
  # message that a user has sent in a thread.
  #
  # Only threads that the user is a member of with a notification level
  # of normal or tracking will be returned.
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
    step :fetch_tracking
    step :fetch_memberships

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
        .strict_loading
        .includes(
          :channel,
          last_reply: %i[user uploads],
          original_message_user: :user_status,
          original_message: [
            :chat_webhook_event,
            :chat_mentions,
            :chat_channel,
            user: :user_status,
          ],
        )
        .joins(:chat_messages, :user_chat_thread_memberships)
        .joins(
          "LEFT JOIN chat_messages original_messages ON chat_threads.original_message_id = original_messages.id",
        )
        .where(
          "chat_threads.channel_id = :channel_id AND chat_messages.chat_channel_id = :channel_id",
          channel_id: channel.id,
        )
        .where("user_chat_thread_memberships.user_id = ?", guardian.user.id)
        .where(
          "user_chat_thread_memberships.notification_level IN (?)",
          [
            Chat::UserChatThreadMembership.notification_levels[:normal],
            Chat::UserChatThreadMembership.notification_levels[:tracking],
          ],
        )
        .where(
          "original_messages.deleted_at IS NULL AND chat_messages.deleted_at IS NULL AND original_messages.id IS NOT NULL",
        )
        .group("chat_threads.id")
        .order("MAX(chat_messages.created_at) DESC")
        .limit(50)
    end

    def fetch_tracking(guardian:, threads:, **)
      context.tracking =
        ::Chat::TrackingStateReportQuery.call(
          guardian: guardian,
          thread_ids: threads.map(&:id),
          include_threads: true,
        ).thread_tracking
    end

    def fetch_memberships(guardian:, threads:, **)
      context.memberships =
        ::Chat::UserChatThreadMembership.where(
          thread_id: threads.map(&:id),
          user_id: guardian.user.id,
        )
    end
  end
end
