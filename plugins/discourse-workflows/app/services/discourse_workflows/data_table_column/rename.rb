# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Rename
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :column_name, :string
      attribute :name, :string

      validates :data_table_id, presence: true
      validates :column_name, presence: true
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
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    policy :column_exists
    policy :not_reserved_column
    policy :name_differs
    policy :name_available

    step :rename_storage_column
    step :log

    private

    def column_exists(data_table:, params:)
      data_table.columns.any? { |c| c["name"] == params.column_name }
    end

    def not_reserved_column(params:)
      DataTables::Types::SYSTEM_COLUMN_NAMES.exclude?(params.column_name)
    end

    def name_available(data_table:, params:)
      data_table.columns.none? { |c| c["name"] == params.name }
    end

    def name_differs(params:)
      params.column_name != params.name
    end

    def rename_storage_column(data_table:, params:)
      DiscourseWorkflows::DataTables::Facade.new(data_table).rename_column!(
        old_name: params.column_name,
        new_name: params.name,
      )
    end

    def log(guardian:, data_table:, params:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_column_renamed",
        subject: data_table.name,
        previous_value: params.column_name,
        new_value: params.name,
      )
    end
  end
end
