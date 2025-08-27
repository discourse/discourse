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
  #  Chat::LookupChannelThreads.call(params: { channel_id: 2, limit: 5, offset: 2 }, guardian: guardian)
  #
  class LookupChannelThreads
    include Service::Base

    THREADS_LIMIT = 10

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id
    #   @option params [Integer] :limit
    #   @option params [Integer] :offset
    #   @return [Service::Base::Context]

    params do
      attribute :channel_id, :integer
      attribute :limit, :integer
      attribute :offset, :integer

      validates :channel_id, presence: true
      validates :limit,
                numericality: {
                  less_than_or_equal_to: THREADS_LIMIT,
                  only_integer: true,
                },
                allow_nil: true

      after_validation do
        self.limit = (limit || THREADS_LIMIT).to_i.clamp(1, THREADS_LIMIT)
        self.offset = [offset || 0, 0].max
      end

      def offset_query
        { offset: offset + limit }.to_query
      end
    end

    model :channel
    policy :threading_enabled_for_channel
    policy :can_view_channel
    model :threads
    model :tracking, optional: true
    model :memberships, optional: true
    model :participants, optional: true
    model :load_more_url, optional: true

    private

    def fetch_channel(params:)
      ::Chat::Channel.strict_loading.includes(:chatable).find_by(id: params.channel_id)
    end

    def threading_enabled_for_channel(channel:)
      channel.threading_enabled?
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_threads(guardian:, channel:, params:)
      Chat::Action::FetchThreads.call(
        user_id: guardian.user.id,
        channel_id: channel.id,
        limit: params.limit,
        offset: params.offset,
      )
    end

    def fetch_tracking(guardian:, threads:)
      ::Chat::TrackingStateReportQuery.call(
        guardian:,
        thread_ids: threads.map(&:id),
        include_threads: true,
      ).thread_tracking
    end

    def fetch_memberships(guardian:, threads:)
      ::Chat::UserChatThreadMembership.where(
        thread_id: threads.map(&:id),
        user_id: guardian.user.id,
      )
    end

    def fetch_participants(threads:)
      ::Chat::ThreadParticipantQuery.call(thread_ids: threads.map(&:id))
    end

    def fetch_load_more_url(channel:, params:)
      ::URI::HTTP.build(
        path: "/chat/api/channels/#{channel.id}/threads",
        query: params.offset_query,
      ).request_uri
    end
  end
end
