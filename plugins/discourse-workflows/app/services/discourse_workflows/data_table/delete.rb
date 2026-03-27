# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Delete
    include Service::Base

    params do
      attribute :data_table_id, :integer
      validates :data_table_id, presence: true
    end

    model :data_table, :find_data_table
    step :log
    step :destroy_data_table
    step :reset_cached_size

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def log(data_table:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_destroyed",
        subject: data_table.name,
      )
    end

    def destroy_data_table(data_table:)
      data_table.destroy!
    end

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
