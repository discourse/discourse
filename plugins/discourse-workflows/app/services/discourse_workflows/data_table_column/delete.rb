# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Delete
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :column_id, :integer

      validates :data_table_id, presence: true
      validates :column_id, presence: true
    end

    model :data_table, :find_data_table

    transaction do
      model :column, :find_column
      step :drop_storage_column
      step :destroy_column
      step :resequence_columns
    end

    step :reset_cached_size

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.includes(:columns).find_by(id: params.data_table_id)
    end

    def find_column(data_table:, params:)
      data_table.columns.find_by(id: params.column_id)
    end

    def drop_storage_column(data_table:, column:)
      DiscourseWorkflows::DataTableStorage.drop_column!(data_table.id, column.name)
    end

    def destroy_column(column:)
      column.destroy!
    end

    def resequence_columns(data_table:)
      data_table.reload
      data_table.reorder_columns!(data_table.columns.order(:position, :id))
    end

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
