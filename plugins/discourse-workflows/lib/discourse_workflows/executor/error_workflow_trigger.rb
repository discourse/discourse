# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ErrorWorkflowTrigger
      def initialize(workflow, steps, execution: nil, execution_mode:)
        @workflow = workflow
        @steps = steps
        @execution = execution
        @execution_mode = execution_mode
      end

      def trigger_error_workflow(error)
        error_workflow = error_workflow_for_failure
        return unless error_workflow&.published?
        return if @execution_mode == :error_mode && error_workflow.id == @workflow.id

        workflow_version = error_workflow.active_version
        trigger_node = trigger_node_for(workflow_version)
        unless trigger_node
          Rails.logger.warn(
            "discourse-workflows: error workflow #{error_workflow.id} has no trigger:error node, skipping error handling",
          )
          return
        end

        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ExecuteWorkflow,
          workflow_id: error_workflow.id,
          workflow_version_id: workflow_version.version_id,
          trigger_node_id: trigger_node["id"],
          trigger_data: build_error_data(error),
          execution_mode: "error_mode",
        )
      end

      private

      def error_workflow_for_failure
        return @workflow.error_workflow if @workflow.error_workflow_id.present?
        @workflow if trigger_node_for(@workflow.active_version)
      end

      def trigger_node_for(workflow_version)
        workflow_version&.nodes&.find { |n| n["type"] == "trigger:error" }
      end

      def build_error_data(error)
        {
          "workflow" => {
            "id" => @workflow.id.to_s,
            "name" => @workflow.name,
          },
          "execution" => {
            "id" => @execution&.id&.to_s,
            "url" => execution_url,
            "retryOf" => nil,
            "error" => serialized_error(error),
            "lastNodeExecuted" => last_failed_step_node_name,
            "mode" => compatible_execution_mode,
          },
        }
      end

      def execution_url
        return nil unless @execution
        DiscourseWorkflows::Execution.admin_execution_url(@workflow.id, @execution.id)
      end

      def serialized_error(error)
        serialized = { "message" => error.message.to_s.truncate(1000), "name" => error.class.name }

        stack = Array(error.backtrace).first(50).join("\n")
        serialized["stack"] = stack.truncate(10_000) if stack.present?

        serialized
      end

      def compatible_execution_mode
        return "error" if @execution_mode == :error_mode
        return "manual" if @execution_mode == :manual

        trigger_node = @execution&.workflow_node(@execution.trigger_node_id)
        %w[trigger:form trigger:webhook].include?(trigger_node&.dig("type")) ? "webhook" : "trigger"
      end

      def last_failed_step_node_name
        step =
          @steps.reverse_each.find do |s|
            s.respond_to?(:error?) ? s.error? : s["status"] == "error"
          end

        step.respond_to?(:node_name) ? step.node_name : step&.dig("node_name")
      end
    end
  end
end
