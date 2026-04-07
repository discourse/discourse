# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Delete
    include Service::Base

    params do
      attribute :data_table_id, :integer
      validates :data_table_id, presence: true
    end

    model :data_table
    policy :data_table_not_in_use

    step :destroy_data_table
    step :log_staff_action

    step :reset_cached_size

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def data_table_not_in_use(data_table:)
      referencing = DiscourseWorkflows::Workflow.referencing_data_table(data_table.id)
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

    def reset_cached_size
      DiscourseWorkflows::DataTableFacade.reset_storage_cache!
    end
  end
end
