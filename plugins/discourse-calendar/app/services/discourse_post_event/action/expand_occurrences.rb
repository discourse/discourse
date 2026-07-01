# frozen_string_literal: true

module DiscoursePostEvent
  module Action
    class ExpandOccurrences < Service::ActionBase
      MAX_LIMIT = 200

      option :event
      option :after
      option :before, optional: true
      option :limit, default: -> { 50 }
      option :current_occurrence_only, default: -> { false }

      def call
        return non_recurring_result unless event.recurring?
        return current_occurrence_result if current_occurrence_only

        build_recurring_occurrences
      end

      private

      def non_recurring_result
        {
          event: event,
          occurrences: [{ starts_at: event.original_starts_at, ends_at: event.original_ends_at }],
        }
      end

      def current_occurrence_result
        starts_at = event.starts_at

        return { event:, occurrences: [] } if starts_at.nil?
        return { event:, occurrences: [] } if after && starts_at < after
        return { event:, occurrences: [] } if before && starts_at >= before

        { event:, occurrences: [{ starts_at:, ends_at: event.ends_at }] }
      end

      def build_recurring_occurrences
        occurrences = []
        current_time = after
        count = 0
        capped_limit = limit.clamp(1, MAX_LIMIT)

        while count < capped_limit
          occurrence = event.calculate_next_occurrence_from(current_time)
          break unless occurrence

          occurrence_starts_at = occurrence[:starts_at]
          break if before && occurrence_starts_at >= before

          occurrences << { starts_at: occurrence_starts_at, ends_at: occurrence[:ends_at] }
          current_time = occurrence_starts_at + 1.second
          count += 1
        end

        { event: event, occurrences: occurrences }
      end
    end
  end
end
