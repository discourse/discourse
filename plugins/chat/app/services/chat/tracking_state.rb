# frozen_string_literal: true

module Chat
  class TrackingStateReport
    attr_accessor :channel_tracking, :thread_tracking

    class TrackingStateInfo
      attr_accessor :unread_count, :mention_count

      def initialize(info)
        @unread_count = info[:unread_count]
        @mention_count = info[:mention_count]
      end

      def to_hash
        to_h
      end

      def to_h
        { unread_count: unread_count, mention_count: mention_count }
      end
    end

    def initialize
      @channel_tracking = {}
      @thread_tracking = {}
    end

    def find_channel(channel_id)
      TrackingStateInfo.new(channel_tracking[channel_id])
    end

    def find_thread(thread_id)
      TrackingStateInfo.new(thread_tracking[thread_id])
    end

    def find_channel_threads(channel_id)
      thread_tracking
        .select { |_, thread| thread[:channel_id] == channel_id }
        .map { |_, thread| TrackingStateInfo.new(thread) }
    end
  end

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
    policy :threaded_discussions_settings_ok
    step :cast_thread_and_channel_ids_to_integer
    model :report

    # @!visibility private
    class Contract
      attribute :channel_ids, default: []
      attribute :thread_ids, default: []
      attribute :include_missing_memberships, default: false
      attribute :include_threads, default: false
    end

    private

    def threaded_discussions_settings_ok(contract:, **)
      return true if !contract.include_threads
      SiteSetting.enable_experimental_chat_threaded_discussions
    end

    def cast_thread_and_channel_ids_to_integer(contract:, **)
      contract.thread_ids = contract.thread_ids.map(&:to_i)
      contract.channel_ids = contract.channel_ids.map(&:to_i)
    end

    def fetch_report(contract:, guardian:, **)
      report = TrackingStateReport.new

      if contract.channel_ids.empty?
        report.channel_tracking = {}
      else
        report.channel_tracking =
          ::Chat::ChannelUnreadsQuery
            .call(
              channel_ids: contract.channel_ids,
              user_id: guardian.user.id,
              include_missing_memberships: contract.include_missing_memberships,
            )
            .map do |ct|
              [ct.channel_id, { mention_count: ct.mention_count, unread_count: ct.unread_count }]
            end
            .to_h
      end

      if contract.include_threads
        if contract.thread_ids.empty? && contract.channel_ids.empty?
          report.thread_tracking = {}
        else
          report.thread_tracking =
            ::Chat::ThreadUnreadsQuery
              .call(
                channel_ids: contract.channel_ids,
                thread_ids: contract.thread_ids,
                user_id: guardian.user.id,
                include_missing_memberships: contract.include_missing_memberships,
              )
              .map do |tt|
                [
                  tt.thread_id,
                  {
                    channel_id: tt.channel_id,
                    mention_count: tt.mention_count,
                    unread_count: tt.unread_count,
                  },
                ]
              end
              .to_h
        end
      else
        report.thread_tracking = {}
      end

      report
    end
  end
end
