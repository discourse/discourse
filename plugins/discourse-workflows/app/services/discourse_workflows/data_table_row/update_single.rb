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

    model :data_table
    model :facade, :build_facade
    policy :within_storage_limit
    model :existing_row
    model :row_input, :build_row_input
    model :row, :update_row
    step :reset_storage_cache

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def build_facade(data_table:)
      DataTables::Facade.new(data_table)
    end

    def within_storage_limit
      DataTables::Facade.within_storage_limit?
    end

    def fetch_existing_row(facade:, params:)
      facade.find_row(params.row_id)
    end

    def build_row_input(facade:, params:)
      facade.build_row_input(data: params.data)
    end

    def update_row(facade:, params:, row_input:)
      facade.update_row(row_id: params.row_id, row_input: row_input)
    end

    def reset_storage_cache
      DiscourseWorkflows::DataTables::Facade.reset_storage_cache!
    end
  end
end
