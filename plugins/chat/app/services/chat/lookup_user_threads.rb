# frozen_string_literal: true

module Chat
  # Gets a list of threads for a user.
  #
  # Only threads that the user is a member of with a notification level
  # of normal or tracking will be returned.
  #
  # @example
  #  Chat::LookupUserThreads.call(guardian: guardian, params: { limit: 5, offset: 2 })
  #
  class LookupUserThreads
    include Service::Base

    THREADS_LIMIT = 10

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :limit
    #   @option params [Integer] :offset
    #   @return [Service::Base::Context]

    params do
      attribute :limit, :integer
      attribute :offset, :integer
    end
    step :set_limit
    step :set_offset
    model :threads
    step :fetch_tracking
    step :fetch_memberships
    step :fetch_participants
    step :build_load_more_url

    private

    def set_limit(params:)
      context[:limit] = (params[:limit] || THREADS_LIMIT).to_i.clamp(1, THREADS_LIMIT)
    end

    def set_offset(params:)
      context[:offset] = [params[:offset] || 0, 0].max
    end

    def fetch_threads(guardian:)
      ::Chat::Thread
        .includes(
          :channel,
          :user_chat_thread_memberships,
          original_message_user: :user_status,
          last_message: [
            :uploads,
            :chat_webhook_event,
            :chat_channel,
            user_mentions: {
              user: :user_status,
            },
            user: :user_status,
          ],
          original_message: [
            :uploads,
            :chat_webhook_event,
            :chat_channel,
            user_mentions: {
              user: :user_status,
            },
            user: :user_status,
          ],
        )
        .joins(
          "INNER JOIN user_chat_thread_memberships ON chat_threads.id = user_chat_thread_memberships.thread_id",
        )
        .joins(
          "LEFT JOIN chat_messages AS last_message ON chat_threads.last_message_id = last_message.id",
        )
        .joins(
          "INNER JOIN chat_messages AS original_message ON chat_threads.original_message_id = original_message.id",
        )
        .where(
          channel_id:
            ::Chat::Channel
              .joins(:user_chat_channel_memberships)
              .where(user_chat_channel_memberships: { user_id: guardian.user.id, following: true })
              .where({ threading_enabled: true, status: ::Chat::Channel.statuses[:open] })
              .select(:id),
        )
        .where("original_message.chat_channel_id = chat_threads.channel_id")
        .where("original_message.deleted_at IS NULL")
        .where("last_message.chat_channel_id = chat_threads.channel_id")
        .where("last_message.deleted_at IS NULL")
        .where("chat_threads.replies_count > 0")
        .where("user_chat_thread_memberships.user_id = ?", guardian.user.id)
        .where(
          "user_chat_thread_memberships.notification_level IN (?)",
          [
            ::Chat::UserChatThreadMembership.notification_levels[:normal],
            ::Chat::UserChatThreadMembership.notification_levels[:watching],
            ::Chat::UserChatThreadMembership.notification_levels[:tracking],
          ],
        )
        .order(
          "CASE WHEN user_chat_thread_memberships.last_read_message_id IS NULL OR user_chat_thread_memberships.last_read_message_id < chat_threads.last_message_id THEN true ELSE false END DESC, last_message.created_at DESC",
        )
        .limit(context.limit)
        .offset(context.offset)
    end

    def fetch_tracking(guardian:, threads:)
      context[:tracking] = ::Chat::TrackingStateReportQuery.call(
        guardian: guardian,
        thread_ids: threads.map(&:id),
        include_threads: true,
      ).thread_tracking
    end

    def fetch_memberships(guardian:, threads:)
      context[:memberships] = ::Chat::UserChatThreadMembership.where(
        thread_id: threads.map(&:id),
        user_id: guardian.user.id,
      )
    end

    def fetch_participants(threads:)
      context[:participants] = ::Chat::ThreadParticipantQuery.call(thread_ids: threads.map(&:id))
    end

    def build_load_more_url
      load_more_params = { limit: context.limit, offset: context.offset + context.limit }.to_query

      context[:load_more_url] = ::URI::HTTP.build(
        path: "/chat/api/me/threads",
        query: load_more_params,
      ).request_uri
    end
  end
end
