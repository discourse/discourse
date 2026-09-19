# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class RunWorkflowCall < ::Jobs::Base
      def execute(args)
        ::DiscourseWorkflows::WorkflowCallContinuation.run!(run_id: args[:run_id])
      end
    end
  end
end
