# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::UpdateSingle
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :row_id, :integer
      attribute :data, default: {}

      validates :data_table_id, presence: true
      validates :row_id, presence: true
    end

    model :data_table, :fetch_data_table
    step :validate_row_data
    model :row, :update_row

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def validate_row_data(data_table:, params:)
      context[:normalized_data] = DiscourseWorkflows::DataTableRow.normalize_row_data(
        data_table,
        params.data,
        fill_missing: false,
      )
    end

    def update_row(data_table:, params:, normalized_data:)
      DiscourseWorkflows::DataTableRowsRepository.new(data_table).update_normalized(
        params.row_id,
        normalized_data,
      )
    end
  end
end
