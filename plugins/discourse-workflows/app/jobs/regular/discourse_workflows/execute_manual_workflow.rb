# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ExecuteManualWorkflow < ::Jobs::Base
      def execute(args)
        execution =
          ::DiscourseWorkflows::Execution.includes(:execution_data, :workflow).find_by(
            id: args[:execution_id],
          )
        return if !execution&.pending?

        if !SiteSetting.discourse_workflows_enabled
          execution.update!(status: :skipped, finished_at: Time.current)
          return
        end

        execution = ::DiscourseWorkflows::Execution.claim_pending(execution)
        return if execution.nil?

        workflow_snapshot = workflow_snapshot_for(execution)
        return if workflow_snapshot.nil?

        user = User.find_by(id: args[:user_id])
        options =
          ::DiscourseWorkflows::Executor::ExecutionOptions.new(
            user: user,
            execution_mode: :manual,
            workflow_snapshot: workflow_snapshot,
            existing_execution: execution,
          )

        ::DiscourseWorkflows::Executor.new(
          execution.workflow,
          execution.trigger_node_id,
          execution.trigger_data || {},
          options,
        ).run
      end

      private

      def workflow_snapshot_for(execution)
        workflow_data = execution.execution_data&.workflow_data
        if workflow_data.blank?
          execution.update!(
            status: :error,
            error: "Workflow snapshot missing",
            finished_at: Time.current,
          )
          return
        end

        ::DiscourseWorkflows::WorkflowSnapshot.new(workflow_data)
      end
    end
  end
end
