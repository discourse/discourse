# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Create
    include Service::Base

    params do
      attribute :name, :string
      attribute :columns, :array, default: []

      validates :name, presence: true
    end

    transaction do
      model :data_table, :create_data_table
      step :create_storage_table
    end

    step :log
    step :reset_cached_size

    private

    def create_data_table(params:)
      data_table = DiscourseWorkflows::DataTable.new(name: params.name)

      params.columns.to_a.each_with_index do |column, index|
        data_table.columns.build(
          name: DiscourseWorkflows::DataTableColumn.definition_name(column),
          column_type: DiscourseWorkflows::DataTableColumn.definition_type(column),
          position: index,
        )
      end

      data_table.save
      data_table
    end

    def create_storage_table(data_table:)
      DiscourseWorkflows::DataTableStorage.create_table!(data_table)
    end

    def log(data_table:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_created",
        subject: data_table.name,
      )
    end

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
