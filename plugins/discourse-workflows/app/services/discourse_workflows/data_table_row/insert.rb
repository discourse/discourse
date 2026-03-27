# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Insert
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :data, default: {}

      validates :data_table_id, presence: true
    end

    model :data_table, :find_data_table
    step :validate_storage_limit
    step :create_row
    step :reset_cached_size

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def validate_storage_limit
      DiscourseWorkflows::DataTableSizeValidator.validate_size!
    end

    def create_row(data_table:, params:)
      context[:row] = DiscourseWorkflows::DataTableRowsRepository.new(data_table).insert(
        params.data,
      )
    end

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
