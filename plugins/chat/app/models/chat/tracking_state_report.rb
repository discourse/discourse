# frozen_string_literal: true

module Chat
  # Represents a report of the tracking state for a user
  # across threads and channels. This is returned by
  # Chat::TrackingStateReportQuery.
  class TrackingStateReport
    attr_accessor :channel_tracking, :thread_tracking

    class TrackingStateInfo
      attr_accessor :unread_count, :mention_count, :last_reply_created_at

      def initialize(info)
        @unread_count = info.present? ? info[:unread_count] : 0
        @mention_count = info.present? ? info[:mention_count] : 0
        @last_reply_created_at = info.present? ? info[:last_reply_created_at] : nil
      end

      def to_hash
        to_h
      end

      def to_h
        {
          unread_count: unread_count,
          mention_count: mention_count,
          last_reply_created_at: last_reply_created_at,
        }
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
      thread_tracking.inject({}) do |result, (thread_id, thread)|
        if thread[:channel_id] == channel_id
          result.merge(thread_id => TrackingStateInfo.new(thread))
        else
          result
        end
      end
    end

    def find_channel_thread_overviews(channel_id)
      thread_tracking.inject({}) do |result, (thread_id, thread)|
        if thread[:channel_id] == channel_id
          result.merge(thread_id => thread[:last_reply_created_at])
        else
          result
        end
      end
    end

    def thread_unread_overview_by_channel
      thread_tracking.inject({}) do |acc, tt|
        thread_id = tt.first
        data = tt.second

        acc[data[:channel_id]] = {} if !acc[data[:channel_id]]
        acc[data[:channel_id]][thread_id] = data[:last_reply_created_at]
        acc
      end
    end
  end
end
