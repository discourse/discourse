# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::Destroy
    include Service::Base

    params do
      attribute :execution_ids, :array
      validates :execution_ids, presence: true
    end

    policy :can_manage_workflows

    transaction do
      step :clear_execution_data
      step :remove_executions
    end

    private

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def clear_execution_data(params:)
      DiscourseWorkflows::ExecutionData.where(execution_id: params.execution_ids).delete_all
    end

    def remove_executions(params:)
      context[:deleted_count] = DiscourseWorkflows::Execution.where(
        id: params.execution_ids,
      ).delete_all
    end
  end
end
