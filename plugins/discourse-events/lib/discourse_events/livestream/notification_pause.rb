# frozen_string_literal: true

module DiscourseEvents
  module Livestream
    # The do not disturb timing a user started from a meeting, recorded under a
    # key the page chose for it so that leaving can end that timing alone.
    #
    # Leaving can reach the server before the pause it ends has been saved, so
    # ending a pause leaves a mark that stops a late start from taking effect.
    # Starting and ending share one lock so neither can slip between the
    # other's check and write.
    class NotificationPause
      CANCELLED = "cancelled"

      # Comfortably longer than a request to start the pause could be delayed.
      CANCELLATION_TTL = 1.day

      attr_reader :user, :key

      def initialize(user:, key:)
        @user = user
        @key = key
      end

      # Returns the new timing, or nil when the pause was already ended.
      def start(ends_at:)
        synchronize do
          next if cancelled?

          timing = user.do_not_disturb_timings.create!(starts_at: Time.zone.now, ends_at:)
          Discourse.redis.setex(redis_key, (timing.ends_at - Time.zone.now).ceil, timing.id)
          timing
        end
      end

      def end
        synchronize do
          timing = find_timing
          Discourse.redis.setex(redis_key, CANCELLATION_TTL.to_i, CANCELLED)
          timing&.destroy!
        end
      end

      private

      def synchronize(&)
        DistributedMutex.synchronize("#{redis_key}:lock", &)
      end

      def cancelled?
        stored_value == CANCELLED
      end

      def find_timing
        return if stored_value.blank? || cancelled?

        user.do_not_disturb_timings.find_by(id: stored_value)
      end

      def stored_value
        Discourse.redis.get(redis_key)
      end

      def redis_key
        "discourse_events:livestream_notification_pause:#{user.id}:#{key}"
      end
    end
  end
end
