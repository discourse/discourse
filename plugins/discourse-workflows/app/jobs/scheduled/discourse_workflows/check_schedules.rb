# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class CheckSchedules < ::Jobs::Scheduled
      every 1.minute

      def execute(_args = nil)
        ::DiscourseWorkflows::Execution::CheckSchedules.call
      end
    end
  end
end
