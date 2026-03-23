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

    model :data_table, :find_data_table
    step :validate_update
    model :rows, :update_matching_rows

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def validate_update(data_table:, params:)
      context[:normalized_filter] = DiscourseWorkflows::DataTableFilter.new(
        data_table,
        params.filter,
      ).normalize(optional: false)
      context[:normalized_data] = DiscourseWorkflows::DataTableRow.normalize_row_data(
        data_table,
        params.data,
        fill_missing: false,
      )
    end

    def update_matching_rows(data_table:, normalized_filter:, normalized_data:)
      DiscourseWorkflows::DataTableRowsRepository.new(data_table).update_many_normalized(
        filter: normalized_filter,
        data: normalized_data,
      )
    end
  end
end
