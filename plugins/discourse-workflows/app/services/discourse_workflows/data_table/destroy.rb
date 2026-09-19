# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Destroy
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      validates :data_table_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    model :referencing_workflows, optional: true
    policy :data_table_not_in_use

    step :delete_data_table
    step :log

    private

    def fetch_referencing_workflows(data_table:)
      workflow_ids =
        DiscourseWorkflows::WorkflowDependency.workflows_referencing(
          "data_table_id",
          data_table.id,
        ).pluck(:workflow_id)
      DiscourseWorkflows::Workflow.where(id: workflow_ids).to_a
    end

    def data_table_not_in_use(referencing_workflows:)
      referencing_workflows.blank?
    end

    def delete_data_table(data_table:)
      data_table.destroy!
    end

    def log(data_table:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_destroyed",
        subject: data_table.name,
      )
    end
  end
end
