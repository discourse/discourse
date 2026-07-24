# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Create
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :name, :string
      attribute :columns, :array, default: []

      validates :name,
                presence: true,
                length: {
                  maximum: 100,
                },
                format: {
                  with: /\A[a-zA-Z_][a-zA-Z0-9_ ]*\z/,
                }

      def normalized_columns
        columns.filter_map do |column|
          column = column.respond_to?(:to_h) ? column.to_h.deep_stringify_keys : column
          name = column["name"].to_s
          type = column["type"].to_s
          next if name.blank? || type.blank?
          next unless DiscourseWorkflows::DataTable::COLUMN_NAME_FORMAT.match?(name)
          next if DiscourseWorkflows::DataTable::VALID_COLUMN_TYPES.exclude?(type)
          next if DiscourseWorkflows::DataTables::Types.system_column?(name)
          next if name.length > DiscourseWorkflows::DataTable::MAX_COLUMN_NAME_LENGTH

          { "name" => name, "type" => type }
        end
      end
    end

    transaction do
      model :data_table, :build_data_table
      step :create_storage_table
    end

    step :log

    private

    def build_data_table(params:)
      DiscourseWorkflows::DataTable.create(name: params.name)
    end

    def create_storage_table(data_table:, params:)
      DiscourseWorkflows::DataTables::Facade.create_table!(
        data_table,
        columns: params.normalized_columns,
      )
    end

    def log(data_table:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_created",
        subject: data_table.name,
      )
    end
  end
end
