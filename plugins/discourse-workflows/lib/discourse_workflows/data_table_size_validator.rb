# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableSizeValidator
    MAX_TOTAL_SIZE_BYTES = 50.megabytes
    CACHE_DURATION_MS = 5_000

    @mutex = Mutex.new

    class << self
      attr_reader :mutex

      def within_limit?(now: Time.zone.now)
        cached_total_size_bytes(now: now) < MAX_TOTAL_SIZE_BYTES
      end

      def reset!
        mutex.synchronize do
          @last_check = nil
          @cached_total_size_bytes = nil
        end
      end

      private

      def cached_total_size_bytes(now:)
        mutex.synchronize do
          refresh_cache!(now: now) if should_refresh?(now: now)
          @cached_total_size_bytes || 0
        end
      end

      def should_refresh?(now:)
        @last_check.nil? || @cached_total_size_bytes.nil? ||
          (now.to_f - @last_check.to_f) * 1000 >= CACHE_DURATION_MS
      end

      def refresh_cache!(now:)
        @cached_total_size_bytes = DataTableStorage.total_size_bytes
        @last_check = now
      end
    end
  end
end
