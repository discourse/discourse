# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Update
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :filter
      attribute :data, default: {}

      validates :data_table_id, presence: true
    end

    model :data_table
    model :facade, :build_facade
    policy :within_storage_limit
    model :query, :build_query
    model :row_input, :build_row_input
    step :update_matching_rows
    step :reset_storage_cache

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def build_facade(data_table:)
      DataTableFacade.new(data_table)
    end

    def within_storage_limit
      DataTableFacade.within_storage_limit?
    end

    def build_query(facade:, params:)
      facade.build_query(filter: params.filter)
    end

    def build_row_input(facade:, params:)
      facade.build_row_input(data: params.data)
    end

    def update_matching_rows(facade:, query:, row_input:)
      context[:updated_count] = facade.update(query:, row_input:)
      fail!("No rows matched filter") if context[:updated_count] == 0
    end

    def reset_storage_cache
      DiscourseWorkflows::DataTableFacade.reset_storage_cache!
    end
  end
end
