# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::Destroy
    include Service::Base

    MAX_BULK_DELETE = 500

    params do
      attribute :execution_ids, :array
      validates :execution_ids, presence: true, length: { maximum: MAX_BULK_DELETE }
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    transaction do
      step :delete_execution_data
      step :remove_workflow_call_run_references
      model :deleted_count, :delete_executions
    end

    private

    def delete_execution_data(params:)
      DiscourseWorkflows::ExecutionData.where(execution_id: params.execution_ids).delete_all
    end

    def remove_workflow_call_run_references(params:)
      DiscourseWorkflows::WorkflowCallRun.remove_execution_references(params.execution_ids)
    end

    def delete_executions(params:)
      DiscourseWorkflows::Execution.where(id: params.execution_ids).delete_all
    end
  end
end
