# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class WaitForResume
      attr_reader :waiting_until, :waiting_config

      def initialize(waiting_until: nil, waiting_config: {})
        @waiting_until = waiting_until
        @waiting_config = waiting_config
      end

      def resolved_waiting_until(now:, max_wait_duration_seconds:)
        max_waiting_until = now + max_wait_duration_seconds
        return max_waiting_until if waiting_until.blank?

        [waiting_until, max_waiting_until].min
      end
    end
  end
end
