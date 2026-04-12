# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Destroy
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :filter

      validates :data_table_id, presence: true
    end

    model :data_table
    model :facade, :build_facade
    model :query, :build_query
    step :destroy_matching_rows
    step :reset_storage_cache

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def build_facade(data_table:)
      DataTables::Facade.new(data_table)
    end

    def build_query(facade:, params:)
      facade.build_query(filter: params.filter)
    end

    def destroy_matching_rows(facade:, query:)
      context[:deleted_count] = facade.delete(query: query)
    end

    def reset_storage_cache
      DiscourseWorkflows::DataTables::Facade.reset_storage_cache!
    end
  end
end
