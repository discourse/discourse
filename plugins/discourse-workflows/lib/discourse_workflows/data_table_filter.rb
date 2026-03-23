# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableFilter
    VALID_TYPES = %w[and or].freeze
    VALID_CONDITIONS = %w[eq neq like ilike gt gte lt lte].freeze

    def initialize(data_table, filter)
      @data_table = data_table
      @filter = filter
      @column_map = DataTableRow.column_map(data_table)
    end

    def normalize(optional: false)
      if @filter.blank?
        return nil if optional
        raise DataTableValidationError, "Filter must not be empty"
      end

      raise DataTableValidationError, "Filter must be an object" unless @filter.is_a?(Hash)

      type = @filter["type"] || @filter[:type] || "and"
      filters = @filter["filters"] || @filter[:filters] || []

      if VALID_TYPES.exclude?(type)
        raise DataTableValidationError, "Unsupported filter type '#{type}'"
      end

      raise DataTableValidationError, "Filter filters must be an array" unless filters.is_a?(Array)

      raise DataTableValidationError, "Filter must not be empty" if filters.empty? && !optional

      {
        "type" => type,
        "filters" => filters.map.with_index { |filter, index| normalize_filter(filter, index) },
      }
    end

    private

    def normalize_filter(filter, index)
      unless filter.is_a?(Hash)
        raise DataTableValidationError, "Filter #{index + 1} must be an object"
      end

      column_name = filter["columnName"] || filter[:columnName]
      condition = filter["condition"] || filter[:condition] || "eq"
      value = filter.key?("value") ? filter["value"] : filter[:value]

      if column_name.blank?
        raise DataTableValidationError, "Filter #{index + 1} is missing columnName"
      end
      if @column_map[column_name].nil?
        raise DataTableValidationError, "Unknown column name '#{column_name}'"
      end

      if VALID_CONDITIONS.exclude?(condition)
        raise DataTableValidationError, "Unsupported filter condition '#{condition}'"
      end

      normalized_value = normalize_value(column_name, condition, value)

      { "columnName" => column_name, "condition" => condition, "value" => normalized_value }
    end

    def normalize_value(column_name, condition, value)
      column = @column_map.fetch(column_name)
      normalized_value =
        DataTableRow.normalize_value(value, DiscourseWorkflows::DataTable.column_type(column))

      if %w[like ilike].include?(condition)
        if normalized_value.nil?
          raise DataTableValidationError,
                "#{condition.upcase} filter value cannot be null or undefined"
        end

        unless normalized_value.is_a?(String)
          raise DataTableValidationError, "#{condition.upcase} filter value must be a string"
        end

        return normalized_value.include?("%") ? normalized_value : "%#{normalized_value}%"
      end

      if %w[gt gte lt lte].include?(condition) && normalized_value.nil?
        raise DataTableValidationError,
              "#{condition.upcase} filter value cannot be null or undefined"
      end

      normalized_value
    end
  end
end
