# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeWaitingExecution < ::Jobs::Base
      def execute(args)
        execution =
          ::DiscourseWorkflows::Execution
            .includes(:execution_data)
            .where(id: args[:execution_id], status: :waiting)
            .lock("FOR UPDATE SKIP LOCKED")
            .first
        return if execution.nil?
        return if execution.waiting_until.present? && execution.waiting_until > Time.current

        config = execution.waiting_config || {}
        timeout_action = config["timeout_action"]

        if timeout_action == "fail"
          execution.fail_with_timeout!
        else
          response_items = config["timeout_response_items"] || passthrough_items(execution)
          ::DiscourseWorkflows::Executor.resume(execution, response_items)
        end
      end

      private

      def passthrough_items(execution)
        entries = execution.execution_data&.entries || {}
        waiting_node_id = execution.waiting_node_id
        steps = entries[waiting_node_id.to_s] || []
        waiting_step = steps.find { |s| s["status"] == "waiting" }
        waiting_step&.dig("input") || [{ "json" => {} }]
      end
    end
  end
end
