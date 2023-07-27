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
  #  Chat::TrackingState.call(channel_ids: [2, 3], thread_ids: [6, 7], guardian: guardian)
  #
  class TrackingState
    include Service::Base

    # @!method call(thread_ids:, channel_ids:, guardian:)
    #   @param [Integer] thread_ids
    #   @param [Integer] channel_ids
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    step :cast_thread_and_channel_ids_to_integer
    model :report

    # @!visibility private
    class Contract
      attribute :channel_ids, default: []
      attribute :thread_ids, default: []
      attribute :include_missing_memberships, default: false
      attribute :include_threads, default: false
      attribute :include_read, default: true
    end

    private

    def cast_thread_and_channel_ids_to_integer(contract:, **)
      contract.thread_ids = contract.thread_ids.map(&:to_i)
      contract.channel_ids = contract.channel_ids.map(&:to_i)
    end

    def fetch_report(contract:, guardian:, **)
      ::Chat::TrackingStateReportQuery.call(
        guardian: guardian,
        channel_ids: contract.channel_ids,
        thread_ids: contract.thread_ids,
        include_missing_memberships: contract.include_missing_memberships,
        include_threads: contract.include_threads,
        include_read: contract.include_read,
      )
    end
  end
end
