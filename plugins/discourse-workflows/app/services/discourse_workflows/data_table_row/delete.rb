# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Delete
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :filter

      validates :data_table_id, presence: true
    end

    model :data_table, :find_data_table
    step :destroy_matching_rows

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def destroy_matching_rows(data_table:, params:)
      context[:deleted_count] = DiscourseWorkflows::DataTableRowsRepository.new(
        data_table,
      ).delete_many(filter: params.filter)
    end
  end
end
