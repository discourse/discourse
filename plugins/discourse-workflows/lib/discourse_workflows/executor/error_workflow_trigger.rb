# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ErrorWorkflowTrigger
      MAX_ERROR_DEPTH = 3

      def initialize(workflow, steps, error_depth:, execution_mode:)
        @workflow = workflow
        @steps = steps
        @error_depth = error_depth
        @execution_mode = execution_mode
      end

      def trigger_error_workflow(error)
        return if @error_depth >= MAX_ERROR_DEPTH
        return unless @execution_mode == :normal

        error_workflow = @workflow.error_workflow
        return unless eligible?(error_workflow)

        trigger_node = error_workflow.nodes.find { |n| n["type"] == "trigger:error" }
        return unless trigger_node

        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ExecuteWorkflow,
          workflow_id: error_workflow.id,
          trigger_node_id: trigger_node["id"],
          trigger_data: build_error_data(error),
          execution_mode: "error_mode",
          error_depth: @error_depth + 1,
        )
      end

      private

      def eligible?(error_workflow)
        error_workflow&.enabled? && error_workflow.id != @workflow.id
      end

      def build_error_data(error)
        {
          error_message: error.message.to_s.truncate(1000),
          failed_node_name: last_failed_step_node_name,
        }
      end

      def last_failed_step_node_name
        step =
          @steps.reverse_each.find do |s|
            s.respond_to?(:error?) ? s.error? : s["status"] == "error"
          end
        return step.node_name if step.respond_to?(:node_name)

        step&.dig("node_name")
      end
    end
  end
end
