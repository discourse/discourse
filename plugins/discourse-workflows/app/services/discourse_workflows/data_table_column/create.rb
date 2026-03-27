# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Create
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :name, :string
      attribute :column_type, :string

      validates :data_table_id, presence: true
      validates :name, presence: true
      validates :column_type, presence: true
    end

    model :data_table, :find_data_table

    transaction do
      model :column, :create_column
      step :add_storage_column
    end

    step :reset_cached_size

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.includes(:columns).find_by(id: params.data_table_id)
    end

    def create_column(data_table:, params:)
      data_table.columns.create(
        name: params.name,
        column_type: params.column_type,
        position: data_table.next_column_position,
      )
    end

    def add_storage_column(data_table:, column:)
      DiscourseWorkflows::DataTableStorage.add_column!(data_table.id, column)
    end

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
