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

    model :data_table
    step :validate_storage_limit
    step :upsert_rows
    step :reset_cached_size

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def validate_storage_limit
      DiscourseWorkflows::DataTableSizeValidator.validate_size!
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

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
