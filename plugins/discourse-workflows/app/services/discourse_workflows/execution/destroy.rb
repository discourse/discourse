# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::Destroy
    include Service::Base

    params do
      attribute :execution_ids, :array
      validates :execution_ids, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    transaction do
      step :delete_execution_data
      model :deleted_count, :delete_executions
    end

    private

    def delete_execution_data(params:)
      DiscourseWorkflows::ExecutionData.where(execution_id: params.execution_ids).delete_all
    end

    def delete_executions(params:)
      DiscourseWorkflows::Execution.where(id: params.execution_ids).delete_all
    end
  end
end
