# frozen_string_literal: true

module Chat
  # Produces the current tracking state for a user for one or more
  # chat channels. This can be further filtered by providing one or
  # more thread IDs for the channel.
  #
  # The goal of this class is to provide an easy way to get
  # tracking state for:
  #
  # * A single channel
  # * A single thread
  # * Multiple channels and threads
  #
  # This is limited to 500 channels and 2000 threads by default,
  # over time we can re-examine this if we find the need to.
  #
  # The user must be a member of these channels -- any channels
  # they are not a member of will always return 0 for unread/mention
  # counts at all times.
  #
  # Only channels with threads enabled will return thread tracking state.
  #
  # @example
  #  Chat::TrackingState.call(params: { channel_ids: [2, 3], thread_ids: [6, 7] }, guardian: guardian)
  #
  class TrackingState
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :thread_ids
    #   @option params [Integer] :channel_ids
    #   @return [Service::Base::Context]

    params do
      attribute :channel_ids, :array, default: []
      attribute :thread_ids, :array, default: []
      attribute :include_missing_memberships, default: false
      attribute :include_threads, default: false
      attribute :include_read, default: true
    end

    model :report

    private

    def fetch_report(params:, guardian:)
      ::Chat::TrackingStateReportQuery.call(
        guardian:,
        **params.slice(
          :channel_ids,
          :thread_ids,
          :include_missing_memberships,
          :include_threads,
          :include_read,
        ),
      )
    end
  end
end
