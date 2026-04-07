# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class CheckStaleTopics < ::Jobs::Scheduled
      every 30.minutes

      def execute(_args = nil)
        ::DiscourseWorkflows::Execution::CheckStaleTopics.call
      end
    end
  end
end
