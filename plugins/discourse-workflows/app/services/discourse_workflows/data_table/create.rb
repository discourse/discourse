# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Create
    include Service::Base

    VALID_COLUMN_TYPES = %w[string number boolean date].freeze
    MAX_COLUMN_NAME_LENGTH = 63
    COLUMN_NAME_FORMAT = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :name, :string
      attribute :columns, :array, default: []

      validates :name, presence: true
    end

    transaction do
      model :data_table, :build_data_table
      step :create_storage_table
    end

    step :log

    private

    def build_data_table(params:)
      data_table = DiscourseWorkflows::DataTable.new(name: params.name)
      data_table.save
      data_table
    end

    def create_storage_table(data_table:, params:)
      columns = normalize_columns(params.columns)
      DiscourseWorkflows::DataTables::Facade.create_table!(data_table, columns: columns)
    end

    def log(data_table:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_created",
        subject: data_table.name,
      )
    end
    def normalize_columns(columns)
      columns.filter_map do |column|
        column = column.respond_to?(:to_h) ? column.to_h.deep_stringify_keys : column
        name = column["name"].to_s
        type = column["type"].to_s
        next if name.blank? || type.blank?
        next unless COLUMN_NAME_FORMAT.match?(name)
        next if VALID_COLUMN_TYPES.exclude?(type)
        next if DiscourseWorkflows::DataTables::Storage::RESERVED_COLUMN_NAMES.include?(name)
        next if name.length > MAX_COLUMN_NAME_LENGTH

        { "name" => name, "type" => type }
      end
    end
  end
end
