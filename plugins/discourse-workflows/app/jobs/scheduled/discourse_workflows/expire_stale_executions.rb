# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ExpireStaleExecutions < ::Jobs::Scheduled
      every 5.minutes

      def execute(_args = nil)
        ::DiscourseWorkflows::Execution::ExpireStale.call
      end
    end
  end
end
