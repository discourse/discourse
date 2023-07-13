# frozen_string_literal: true

module Chat
  # Represents a report of the tracking state for a user
  # across threads and channels. This is returned by
  # Chat::TrackingStateReportQuery.
  class TrackingStateReport
    attr_accessor :channel_tracking, :thread_tracking

    class TrackingStateInfo
      attr_accessor :unread_count, :mention_count

      def initialize(info)
        @unread_count = info.present? ? info[:unread_count] : 0
        @mention_count = info.present? ? info[:mention_count] : 0
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
        .map { |thread_id, thread| [thread_id, TrackingStateInfo.new(thread)] }
        .to_h
    end
  end
end
