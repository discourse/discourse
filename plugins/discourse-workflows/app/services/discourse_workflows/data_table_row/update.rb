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
    step :validate_storage_limit
    step :normalize_filter
    step :normalize_data
    step :update_matching_rows
    step :reset_cached_size

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def validate_storage_limit
      DiscourseWorkflows::DataTableSizeValidator.validate_size!
    end

    def normalize_filter(data_table:, params:)
      context[:normalized_filter] = DiscourseWorkflows::DataTableFilter.new(
        data_table,
        params.filter,
      ).normalize(optional: false)
    end

    def normalize_data(data_table:, params:)
      context[:normalized_data] = DiscourseWorkflows::DataTableRow.normalize_row_data(
        data_table,
        params.data,
        fill_missing: false,
      )
    end

    def update_matching_rows(data_table:, normalized_filter:, normalized_data:)
      context[:updated_count] = DiscourseWorkflows::DataTableRowsRepository.new(
        data_table,
      ).update_many_normalized(filter: normalized_filter, data: normalized_data)

      fail!("No rows matched filter") if context[:updated_count] == 0
    end

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
