# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::BulkDestroy
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :row_ids, :array

      before_validation { self.row_ids = row_ids.map(&:to_i).uniq if row_ids.present? }

      validates :data_table_id, presence: true
      validates :row_ids, presence: true
    end

    model :data_table
    model :facade, :build_facade
    model :deleted_count, :destroy_rows
    step :reset_storage_cache

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def build_facade(data_table:)
      DataTableFacade.new(data_table)
    end

    def destroy_rows(facade:, params:)
      facade.delete_rows(params.row_ids)
    end

    def reset_storage_cache
      DiscourseWorkflows::DataTableFacade.reset_storage_cache!
    end
  end
end
