# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Get
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :filter
      attribute :limit, :integer
      attribute :sort_by, :string
      attribute :sort_direction, :string

      validates :data_table_id, presence: true
    end

    model :data_table, :find_data_table
    step :query_rows

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def query_rows(data_table:, params:)
      result =
        DiscourseWorkflows::DataTableRowsRepository.new(data_table).get_many_and_count(
          filter: params.filter,
          limit: params.limit,
          sort_by: params.sort_by,
          sort_direction: params.sort_direction,
        )

      context[:rows] = result[:rows]
      context[:count] = result[:count]
    end
  end
end
