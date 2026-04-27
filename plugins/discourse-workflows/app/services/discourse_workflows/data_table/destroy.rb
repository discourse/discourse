# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Destroy
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      validates :data_table_id, presence: true
    end

    model :data_table
    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    policy :data_table_not_in_use

    step :destroy_data_table
    step :log_staff_action

    private

    def data_table_not_in_use(data_table:)
      workflow_ids =
        DiscourseWorkflows::WorkflowDependency.workflows_referencing(
          "data_table_id",
          data_table.id,
        ).pluck(:workflow_id)
      referencing = DiscourseWorkflows::Workflow.where(id: workflow_ids)
      context[:referencing_workflows] = referencing
      referencing.blank?
    end

    def log_staff_action(data_table:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_destroyed",
        subject: data_table.name,
      )
    end

    def destroy_data_table(data_table:)
      data_table.destroy!
    end
  end
end
