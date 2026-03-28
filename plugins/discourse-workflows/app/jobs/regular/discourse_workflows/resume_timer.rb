# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeTimer < ::Jobs::Base
      def execute(args)
        execution = ::DiscourseWorkflows::Execution.find_by(id: args[:execution_id])
        return if execution.nil?
        return unless execution.waiting?
        return unless execution.waiting_config&.dig("wait_type") == "timer"

        waiting_step = execution.steps.find_by(node_id: execution.waiting_node_id, status: :waiting)
        return if waiting_step.nil?

        input_items = waiting_step.input || [{ "json" => {} }]
        ::DiscourseWorkflows::Executor.resume(execution, input_items)
      end
    end
  end
end
