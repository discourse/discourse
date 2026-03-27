# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Move
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :column_id, :integer
      attribute :position, :integer

      validates :data_table_id, presence: true
      validates :column_id, presence: true
      validates :position,
                presence: true,
                numericality: {
                  only_integer: true,
                  greater_than_or_equal_to: 0,
                }
    end

    model :data_table, :find_data_table

    transaction do
      model :column, :find_column
      step :move_column
    end

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.includes(:columns).find_by(id: params.data_table_id)
    end

    def find_column(data_table:, params:)
      data_table.columns.find_by(id: params.column_id)
    end

    def move_column(data_table:, column:, params:)
      ordered_columns = data_table.columns.order(:position, :id).to_a
      target_position = params.position

      if target_position >= ordered_columns.length
        raise DataTableValidationError,
              "Position must be between 0 and #{ordered_columns.length - 1}"
      end

      ordered_columns.delete(column)
      ordered_columns.insert(target_position, column)

      data_table.reorder_columns!(ordered_columns)
      data_table.reload
    end
  end
end
