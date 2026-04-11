# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Destroy
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :column_name, :string

      validates :data_table_id, presence: true
      validates :column_name, presence: true
    end

    model :data_table
    policy :column_exists
    policy :not_reserved_column

    step :drop_storage_column
    step :log
    step :reset_storage_cache

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def column_exists(data_table:, params:)
      data_table.columns.any? { |c| c["name"] == params.column_name }
    end

    def not_reserved_column(params:)
      DataTableStorage::RESERVED_COLUMN_NAMES.exclude?(params.column_name)
    end

    def drop_storage_column(data_table:, params:)
      DiscourseWorkflows::DataTableFacade.new(data_table).drop_column!(params.column_name)
    end

    def log(guardian:, data_table:, params:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_column_destroyed",
        subject: data_table.name,
        column_name: params.column_name,
      )
    end

    def reset_storage_cache
      DiscourseWorkflows::DataTableFacade.reset_storage_cache!
    end
  end
end
