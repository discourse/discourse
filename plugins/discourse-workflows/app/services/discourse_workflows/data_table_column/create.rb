# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Create
    include Service::Base

    VALID_COLUMN_TYPES = %w[string number boolean date].freeze
    MAX_COLUMNS = 30
    MAX_COLUMN_NAME_LENGTH = 63

    params do
      attribute :data_table_id, :integer
      attribute :name, :string
      attribute :column_type, :string

      validates :data_table_id, presence: true
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
      validates :column_type, presence: true, inclusion: { in: VALID_COLUMN_TYPES }
    end

    model :data_table
    policy :column_limit_not_reached

    step :add_storage_column
    step :log

    private

    def column_limit_not_reached(data_table:)
      data_table.columns.size < MAX_COLUMNS
    end

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
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
