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
    model :row
    step :destroy_row
    step :reset_cached_size

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def fetch_row(data_table:, params:)
      DiscourseWorkflows::DataTableRowsRepository.new(data_table).find(params.row_id)
    end

    def destroy_row(data_table:, params:)
      DiscourseWorkflows::DataTableRowsRepository.new(data_table).delete(params.row_id)
    end

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
