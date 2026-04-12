# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Rename
    include Service::Base

    MAX_COLUMN_NAME_LENGTH = 63

    params do
      attribute :data_table_id, :integer
      attribute :column_name, :string
      attribute :name, :string

      validates :data_table_id, presence: true
      validates :column_name, presence: true
      validates :name,
                presence: true,
                length: {
                  maximum: MAX_COLUMN_NAME_LENGTH,
                },
                format: {
                  with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/,
                  message:
                    "must start with a letter or underscore and contain only letters, numbers, and underscores",
                },
                exclusion: {
                  in: DataTables::Storage::RESERVED_COLUMN_NAMES,
                  message: "is reserved",
                }
    end

    model :data_table
    policy :column_exists
    policy :not_reserved_column
    policy :name_differs
    policy :name_available

    step :rename_storage_column
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
      DataTables::Storage::RESERVED_COLUMN_NAMES.exclude?(params.column_name)
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

    def reset_storage_cache
      DiscourseWorkflows::DataTables::Facade.reset_storage_cache!
    end
  end
end
