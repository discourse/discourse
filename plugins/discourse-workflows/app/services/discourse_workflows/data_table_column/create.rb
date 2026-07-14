# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Create
    include Service::Base
    include Concerns::DataTableServiceHelpers

    MAX_COLUMNS = 30

    params do
      attribute :data_table_id, :integer
      attribute :name, :string
      attribute :column_type, :string

      validates :data_table_id, presence: true
      validates :name,
                presence: true,
                length: {
                  maximum: DiscourseWorkflows::DataTable::MAX_COLUMN_NAME_LENGTH,
                },
                format: {
                  with: DiscourseWorkflows::DataTable::COLUMN_NAME_FORMAT,
                  message:
                    "must start with a letter or underscore and contain only letters, numbers, and underscores",
                },
                exclusion: {
                  in: DataTables::Types::SYSTEM_COLUMN_NAMES,
                  message: "is reserved",
                }
      validates :column_type,
                presence: true,
                inclusion: {
                  in: DiscourseWorkflows::DataTable::VALID_COLUMN_TYPES,
                }
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    policy :column_limit_not_reached

    step :add_storage_column
    step :log

    private

    def column_limit_not_reached(data_table:)
      data_table.columns.size < MAX_COLUMNS
    end

    def add_storage_column(data_table:, params:)
      DiscourseWorkflows::DataTables::Facade.new(data_table).add_column!(
        params.name,
        params.column_type,
      )
    end

    def log(guardian:, data_table:, params:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_column_created",
        subject: data_table.name,
        column_name: params.name,
        column_type: params.column_type,
      )
    end
  end
end
