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

      after_validation do
        self.limit = (limit || THREADS_LIMIT).to_i.clamp(1, THREADS_LIMIT)
        self.offset = [offset || 0, 0].max
      end
    end

    model :threads
    step :fetch_tracking
    step :fetch_memberships
    step :fetch_participants
    step :build_load_more_url

    private

    def fetch_threads(guardian:, params:)
      ::Chat::Thread
        .viewable_by_user(guardian.user)
        .includes(
          :channel,
          :user_chat_thread_memberships,
          original_message_user: :user_status,
          last_message: [
            :uploads,
            :chat_webhook_event,
            :chat_channel,
            { user_mentions: { user: :user_status } },
            { user: :user_status },
          ],
          original_message: [
            :uploads,
            :chat_webhook_event,
            :chat_channel,
            { user_mentions: { user: :user_status } },
            { user: :user_status },
          ],
        )
        .order(<<~SQL)
          CASE WHEN user_chat_thread_memberships.last_read_message_id IS NULL
               OR user_chat_thread_memberships.last_read_message_id < chat_threads.last_message_id
          THEN 1 ELSE 0 END DESC,
          viewable_lm.created_at DESC
        SQL
        .limit(params.limit)
        .offset(params.offset)
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

    def build_load_more_url(params:)
      load_more_params = { limit: params.limit, offset: params.offset + params.limit }.to_query

      context[:load_more_url] = ::URI::HTTP.build(
        path: "/chat/api/me/threads",
        query: load_more_params,
      ).request_uri
    end
  end
end
