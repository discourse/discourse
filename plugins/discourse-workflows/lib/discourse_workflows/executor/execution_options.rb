# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    ExecutionOptions =
      Data.define(
        :user,
        :execution_mode,
        :draft_execution,
        :workflow_version,
        :workflow_snapshot,
        :existing_execution,
        :webhook_context,
        :workflow_call_stack,
        :workflow_call_caller,
        :workflow_call_run_id,
        :workflow_call_child,
      ) do
        def initialize(
          user: nil,
          execution_mode: :normal,
          draft_execution: false,
          workflow_version: nil,
          workflow_snapshot: nil,
          existing_execution: nil,
          webhook_context: nil,
          workflow_call_stack: [],
          workflow_call_caller: nil,
          workflow_call_run_id: nil,
          workflow_call_child: false
        )
          super
        end

        def workflow_call_child?
          workflow_call_run_id.present? || workflow_call_child
        end
      end
  end
end
