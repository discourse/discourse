# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableSizeValidator
    MAX_TOTAL_SIZE_BYTES = 50.megabytes
    CACHE_DURATION_MS = 5_000

    class << self
      def validate_size!(now: Time.zone.now)
        current = cached_total_size_bytes(now: now)
        return if current < MAX_TOTAL_SIZE_BYTES

        raise DataTableValidationError,
              "Data table storage limit exceeded (#{(current / 1.megabyte.to_f).round(1)}MB / #{(MAX_TOTAL_SIZE_BYTES / 1.megabyte.to_f).round(1)}MB)"
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

      def mutex
        @mutex ||= Mutex.new
      end
    end
  end
end
