# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Get
    include Service::Base

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    params do
      attribute :data_table_id, :integer
      attribute :filter
      attribute :limit, :integer
      attribute :offset, :integer
      attribute :sort_by, :string
      attribute :sort_direction, :string

      validates :data_table_id, presence: true

      before_validation { self.limit = [[limit.to_i, 1].max, MAX_LIMIT].min if limit.present? }
    end

    model :data_table
    model :facade, :build_facade
    model :query, :build_query
    model :query_result, :execute_query

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def build_facade(data_table:)
      DataTables::Facade.new(data_table)
    end

    def build_query(facade:, params:)
      facade.build_query(
        filter: params.filter,
        limit: params.limit || DEFAULT_LIMIT,
        offset: params.offset,
        sort_by: params.sort_by,
        sort_direction: params.sort_direction,
        optional_filter: true,
      )
    end

    def execute_query(facade:, query:)
      facade.query(query)
    end
  end
end
