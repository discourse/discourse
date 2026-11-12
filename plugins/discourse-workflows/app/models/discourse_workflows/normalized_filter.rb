# frozen_string_literal: true

module DiscourseWorkflows
  class NormalizedFilter
    include ActiveModel::Validations

    VALID_TYPES = %w[and or].freeze
    VALID_CONDITIONS = %w[eq neq like ilike not_ilike gt gte lt lte].freeze
    LIKE_CONDITIONS = %w[like ilike not_ilike].freeze
    COMPARISON_CONDITIONS = %w[gt gte lt lte].freeze
    MAX_FILTER_CONDITIONS = 50

    attr_reader :value

    validate :check_normalization_error

    def initialize(data_table:, filter:, optional: false)
      @column_map = data_table.columns.index_by { |column| DataTable.column_name(column) }
      @value = normalize(filter, optional)
    rescue ArgumentError => e
      @normalization_error = e.message
      @value = nil
    end

    def has_changes_to_save?
      true
    end

    private

    def check_normalization_error
      errors.add(:base, @normalization_error) if @normalization_error.present?
    end

    def normalize(filter, optional)
      return nil if filter.blank? && optional
      validate_filter_structure!(filter)

      normalized = filter.with_indifferent_access
      type = validated_type(normalized[:type])
      filters = validated_filters_array(normalized[:filters], optional)

      { "type" => type, "filters" => filters.map.with_index { |f, i| normalize_single(f, i) } }
    end

    def validate_filter_structure!(filter)
      raise ArgumentError, "Filter must not be empty" if filter.blank?
      raise ArgumentError, "Filter must be an object" unless filter.is_a?(Hash)
    end

    def validated_type(type)
      type ||= "and"
      raise ArgumentError, "Unsupported filter type '#{type}'" if VALID_TYPES.exclude?(type)
      type
    end

    def validated_filters_array(filters, optional)
      filters ||= []
      raise ArgumentError, "Filter filters must be an array" unless filters.is_a?(Array)
      raise ArgumentError, "Filter must not be empty" if filters.empty? && !optional
      if filters.size > MAX_FILTER_CONDITIONS
        raise ArgumentError, "Filter must not have more than #{MAX_FILTER_CONDITIONS} conditions"
      end
      filters
    end

    def normalize_single(filter, index)
      raise ArgumentError, "Filter #{index + 1} must be an object" unless filter.is_a?(Hash)

      filter = filter.with_indifferent_access
      column_name = validated_column_name(filter[:columnName], index)
      condition = validated_condition(filter[:condition])

      {
        "columnName" => column_name,
        "condition" => condition,
        "value" => normalize_value(column_name, condition, filter[:value]),
      }
    end

    def validated_column_name(column_name, index)
      raise ArgumentError, "Filter #{index + 1} is missing columnName" if column_name.blank?
      raise ArgumentError, "Unknown column name '#{column_name}'" if @column_map[column_name].nil?
      column_name
    end

    def validated_condition(condition)
      condition ||= "eq"
      if VALID_CONDITIONS.exclude?(condition)
        raise ArgumentError, "Unsupported filter condition '#{condition}'"
      end
      condition
    end

    def normalize_value(column_name, condition, value)
      column = @column_map.fetch(column_name)
      normalized = DataTableRow.normalize_value(value, DataTable.column_type(column))

      return normalize_like_value(normalized, condition) if LIKE_CONDITIONS.include?(condition)
      if COMPARISON_CONDITIONS.include?(condition) && normalized.nil?
        raise ArgumentError, "#{condition.upcase} filter value cannot be null or undefined"
      end

      normalized
    end

    def normalize_like_value(normalized, condition)
      if normalized.nil?
        raise ArgumentError, "#{condition.upcase} filter value cannot be null or undefined"
      end
      unless normalized.is_a?(String)
        raise ArgumentError, "#{condition.upcase} filter value must be a string"
      end
      normalized
    end
  end
end
