# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeExecution < ::Jobs::Base
      def execute(args)
        ::DiscourseWorkflows::Execution::Resume.call(
          params: {
            execution_id: args[:execution_id],
            approved: args[:approved],
          },
        )
      end
    end
  end
end
