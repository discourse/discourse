# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTest::Action::EnqueueRun < Service::ActionBase
    option :workflow_test
    option :user

    def call
      execution = nil
      workflow_test.with_lock do
        execution =
          Execution.create_pending_simulation!(
            workflow: workflow_test.workflow,
            trigger_node_id: workflow_test.trigger_node_id,
            trigger_data: workflow_test.trigger_data,
            workflow_test:,
          )
        workflow_test.update!(latest_execution_id: execution.id)
      end

      begin
        Jobs.enqueue(
          Jobs::DiscourseWorkflows::RunSimulation,
          execution_id: execution.id,
          user_id: user.id,
        )
      rescue StandardError => error
        execution.update!(
          status: :error,
          error: error.message.to_s.truncate(1000),
          finished_at: Time.current,
        )
        ExecutionProgressPublisher.publish(execution, refresh: true)
        raise
      end

      execution
    end
  end
end
