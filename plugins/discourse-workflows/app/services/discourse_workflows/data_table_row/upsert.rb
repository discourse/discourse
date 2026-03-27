# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Upsert
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :filter
      attribute :data, default: {}

      validates :data_table_id, presence: true
    end

    model :data_table, :find_data_table
    step :upsert_rows

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def upsert_rows(data_table:, params:)
      result =
        DiscourseWorkflows::DataTableRowsRepository.new(data_table).upsert(
          filter: params.filter,
          data: params.data,
        )

      context[:operation] = result[:operation]
      context[:row] = result[:row]
      context[:updated_count] = result[:updated_count]
    end
  end
end
