# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::DestroySingle
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :row_id, :integer

      validates :data_table_id, presence: true
      validates :row_id, presence: true
    end

    model :data_table
    model :facade, :build_facade
    model :row
    step :destroy_row
    step :invalidate_storage_size

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def build_facade(data_table:)
      DataTables::Facade.new(data_table)
    end

    def fetch_row(facade:, params:)
      facade.find_row(params.row_id)
    end

    def destroy_row(facade:, params:)
      facade.delete_row(params.row_id)
    end

    def invalidate_storage_size
      DiscourseWorkflows::DataTables::Facade.reset_storage_cache!
    end
  end
end
