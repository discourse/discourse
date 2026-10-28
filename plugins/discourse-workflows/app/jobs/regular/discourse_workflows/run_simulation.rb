# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class RunSimulation < ::Jobs::Base
      sidekiq_options queue: "low"

      def execute(args)
        execution =
          ::DiscourseWorkflows::Execution.includes(
            :execution_data,
            :workflow,
            :workflow_test,
          ).find_by(id: args[:execution_id])
        return if !execution&.pending? || !execution.simulation?

        if !SiteSetting.enable_discourse_workflows
          execution.update!(status: :skipped, finished_at: Time.current)
          ::DiscourseWorkflows::ExecutionProgressPublisher.publish(execution, refresh: true)
          return
        end

        execution = ::DiscourseWorkflows::Execution.claim_pending(execution)
        return if execution.nil?

        workflow_data = execution.execution_data&.workflow_data
        if workflow_data.blank?
          execution.update!(
            status: :error,
            error: "Workflow snapshot missing",
            finished_at: Time.current,
          )
          ::DiscourseWorkflows::ExecutionProgressPublisher.publish(execution, refresh: true)
          return
        end

        workflow_test = execution.workflow_test
        options =
          ::DiscourseWorkflows::Executor::ExecutionOptions.new(
            user: User.find_by(id: args[:user_id]),
            execution_mode: :simulation,
            draft_execution: true,
            workflow_snapshot: ::DiscourseWorkflows::WorkflowSnapshot.new(workflow_data),
            existing_execution: execution,
            workflow_test: workflow_test && test_data_for(workflow_test, execution),
            now: workflow_test&.captured_at,
          )

        ::DiscourseWorkflows::Executor.new(
          execution.workflow,
          execution.trigger_node_id,
          execution.trigger_data || {},
          options,
        ).run
      end

      private

      def test_data_for(workflow_test, execution)
        ::DiscourseWorkflows::Simulation::TestData.new(
          captured_outputs: workflow_test.captured_outputs,
          pasted_responses: workflow_test.pasted_responses,
          capture: true,
          checks: execution.execution_data.simulation&.dig("checks") || workflow_test.checks,
          on_complete:
            lambda do |finished_execution, run_state|
              workflow_test.record_captures!(
                finished_execution,
                run_state.captures,
                pinned_at: run_state.now,
              )
            end,
        )
      end
    end
  end
end
