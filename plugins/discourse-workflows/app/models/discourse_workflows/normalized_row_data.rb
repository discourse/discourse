# frozen_string_literal: true

module DiscourseWorkflows
  class NormalizedRowData
    include ActiveModel::Validations

    attr_reader :columns

    validate :check_normalization_error

    def initialize(data_table:, data:, fill_missing: false)
      @columns = DataTableRow.normalize_row_data(data_table, data, fill_missing: fill_missing)
    rescue ArgumentError => e
      @normalization_error = e.message
      @columns = {}
    end

    def has_changes_to_save?
      true
    end

    private

    def check_normalization_error
      errors.add(:base, @normalization_error) if @normalization_error.present?
    end
  end
end
