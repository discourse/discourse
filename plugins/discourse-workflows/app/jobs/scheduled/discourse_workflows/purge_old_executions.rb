# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class PurgeOldExecutions < ::Jobs::Scheduled
      every 1.day

      def execute(_args = nil)
        ::DiscourseWorkflows::Execution.purge_old
      end
    end
  end
end
