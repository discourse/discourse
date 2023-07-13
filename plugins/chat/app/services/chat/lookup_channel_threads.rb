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
  #  Chat::LookupChannelThreads.call(channel_id: 2, guardian: guardian, limit: 5, offset: 2)
  #
  class LookupChannelThreads
    include Service::Base

    THREADS_LIMIT = 10

    # @!method call(channel_id:, guardian:, limit: nil, offset: nil)
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @param [Integer] limit
    #   @param [Integer] offset
    #   @return [Service::Base::Context]

    policy :threaded_discussions_enabled
    contract
    step :set_limit
    step :set_offset
    model :channel
    policy :threading_enabled_for_channel
    policy :can_view_channel
    model :threads
    step :fetch_tracking
    step :fetch_memberships
    step :build_load_more_url

    # @!visibility private
    class Contract
      attribute :channel_id, :integer
      validates :channel_id, presence: true

      attribute :limit, :integer
      attribute :offset, :integer
    end

    private

    def set_limit(contract:, **)
      context.limit = (contract.limit || THREADS_LIMIT).to_i.clamp(1, THREADS_LIMIT)
    end

    def set_offset(contract:, **)
      context.offset = [contract.offset || 0, 0].max
    end

    def threaded_discussions_enabled
      ::SiteSetting.enable_experimental_chat_threaded_discussions
    end

    def fetch_channel(contract:, **)
      ::Chat::Channel.strict_loading.includes(:chatable).find_by(id: contract.channel_id)
    end

    def threading_enabled_for_channel(channel:, **)
      channel.threading_enabled
    end

    def can_view_channel(guardian:, channel:, **)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_threads(guardian:, channel:, **)
      read_threads = []

      unread_threads =
        threads_query(guardian, channel)
          .where(<<~SQL)
            user_chat_thread_memberships_chat_threads.last_read_message_id IS NULL
              OR tracked_threads_subquery.latest_message_id > user_chat_thread_memberships_chat_threads.last_read_message_id
          SQL
          .order("tracked_threads_subquery.latest_message_created_at DESC")
          .limit(context.limit)
          .offset(context.offset)
          .to_a

      # We do this to avoid having to query additional threads if the user
      # already has a lot of unread threads.
      if unread_threads.length < context.limit
        final_limit = context.limit - unread_threads.length
        final_offset = context.offset + unread_threads.length

        read_threads =
          threads_query(guardian, channel)
            .where(<<~SQL)
              tracked_threads_subquery.latest_message_id <= user_chat_thread_memberships_chat_threads.last_read_message_id
            SQL
            .order("tracked_threads_subquery.latest_message_created_at DESC")
            .limit(final_limit)
            .offset(final_offset)
            .to_a
      end

      unread_threads + read_threads
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

    def threads_query(guardian, channel)
      ::Chat::Thread
        .strict_loading
        .includes(
          :channel,
          :user_chat_thread_memberships,
          original_message_user: :user_status,
          last_message: [
            :chat_webhook_event,
            :chat_channel,
            chat_mentions: {
              user: :user_status,
            },
            user: :user_status,
          ],
          original_message: [
            :uploads,
            :chat_webhook_event,
            :chat_channel,
            chat_mentions: {
              user: :user_status,
            },
            user: :user_status,
          ],
        )
        .joins(
          "JOIN (#{tracked_threads_subquery(guardian, channel)}) tracked_threads_subquery
              ON tracked_threads_subquery.thread_id = chat_threads.id",
        )
        .joins(:user_chat_thread_memberships)
        .joins(
          "LEFT JOIN chat_messages original_messages ON chat_threads.original_message_id = original_messages.id",
        )
        .where("original_messages.deleted_at IS NULL")
        .where(user_chat_thread_memberships_chat_threads: { user_id: guardian.user.id })
    end

    def tracked_threads_subquery(guardian, channel)
      ::Chat::Thread
        .strict_loading
        .joins(:chat_messages, :user_chat_thread_memberships)
        .joins(
          "LEFT JOIN chat_messages original_messages ON chat_threads.original_message_id = original_messages.id",
        )
        .joins(
          "LEFT JOIN chat_messages last_message ON chat_threads.last_message_id = last_message.id",
        )
        .where(user_chat_thread_memberships: { user_id: guardian.user.id })
        .where(
          "chat_threads.channel_id = :channel_id AND chat_messages.chat_channel_id = :channel_id",
          channel_id: channel.id,
        )
        .where(
          "user_chat_thread_memberships.notification_level IN (?)",
          [
            ::Chat::UserChatThreadMembership.notification_levels[:normal],
            ::Chat::UserChatThreadMembership.notification_levels[:tracking],
          ],
        )
        .where(
          "original_messages.deleted_at IS NULL AND chat_messages.deleted_at IS NULL AND original_messages.id IS NOT NULL AND last_message.deleted_at IS NULL",
        )
        .select(
          "chat_threads.id AS thread_id, last_message.created_at AS latest_message_created_at, last_message.id AS latest_message_id",
        )
        .to_sql
    end

    def build_load_more_url(contract:, **)
      load_more_params = { offset: context.offset + context.limit }.to_query
      context.load_more_url =
        ::URI::HTTP.build(
          path: "/chat/api/channels/#{contract.channel_id}/threads",
          query: load_more_params,
        ).request_uri
    end
  end
end
