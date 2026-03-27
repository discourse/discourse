# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Rename
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :column_id, :integer
      attribute :name, :string

      validates :data_table_id, presence: true
      validates :column_id, presence: true
      validates :name, presence: true
    end

    model :data_table, :find_data_table

    transaction do
      model :column, :find_column
      step :rename_column
      step :rename_storage_column
    end

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.includes(:columns).find_by(id: params.data_table_id)
    end

    def find_column(data_table:, params:)
      data_table.columns.find_by(id: params.column_id)
    end

    def rename_column(column:, params:)
      column.update(name: params.name)
    end

    def rename_storage_column(data_table:, column:)
      DiscourseWorkflows::DataTableStorage.rename_column!(
        data_table.id,
        column.name_before_last_save,
        column.name,
      )

      data_table.reload
    end
  end
end
