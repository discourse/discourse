# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ExpireWaitingExecutions < ::Jobs::Scheduled
      every 1.minute

      def execute(_args = nil)
        ::DiscourseWorkflows::Execution::ExpireWaiting.call
      end
    end
  end
end
