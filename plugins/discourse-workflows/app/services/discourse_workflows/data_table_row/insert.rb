# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Insert
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :data, default: {}

      validates :data_table_id, presence: true
    end

    model :data_table, :find_data_table
    step :create_row

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def create_row(data_table:, params:)
      context[:row] = DiscourseWorkflows::DataTableRowsRepository.new(data_table).insert(
        params.data,
      )
    end
  end
end
