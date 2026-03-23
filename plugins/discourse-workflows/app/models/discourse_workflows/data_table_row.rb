# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow
    MAX_CELL_LENGTH = 50_000

    class << self
      def column_map(data_table)
        data_table.columns.index_by { |column| DiscourseWorkflows::DataTable.column_name(column) }
      end

      def normalize_row_data(data_table, data, fill_missing:)
        raise DataTableValidationError, "Row data must be an object" unless data.is_a?(Hash)

        normalized_data = data.stringify_keys
        columns = column_map(data_table)
        unknown_columns = normalized_data.keys - columns.keys

        if unknown_columns.any?
          raise DataTableValidationError, "Unknown column name '#{unknown_columns.first}'"
        end

        if fill_missing
          columns.each_with_object({}) do |(name, column), result|
            result[name] = normalize_value(
              normalized_data[name],
              DiscourseWorkflows::DataTable.column_type(column),
            )
          end
        else
          normalized_data.each_with_object({}) do |(name, value), result|
            result[name] = normalize_value(
              value,
              DiscourseWorkflows::DataTable.column_type(columns.fetch(name)),
            )
          end
        end
      end

      def normalize_value(value, type)
        type = type.to_s
        return nil if value.nil?
        return nil if value == "" && %w[number date].include?(type)

        case type
        when "number"
          normalize_number(value)
        when "boolean"
          normalize_boolean(value)
        when "date"
          normalize_date(value)
        else
          str = value.to_s
          if str.length > MAX_CELL_LENGTH
            raise DataTableValidationError,
                  "Value exceeds maximum cell length of #{MAX_CELL_LENGTH} characters"
          end
          str
        end
      end

      private

      def normalize_number(value)
        return value if value.is_a?(Numeric)

        if value.to_s.match?(/\A-?\d+\z/)
          Integer(value, 10)
        else
          Float(value)
        end
      rescue ArgumentError, TypeError
        raise DataTableValidationError, "Value '#{value}' does not match column type 'number'"
      end

      def normalize_boolean(value)
        return value if value == true || value == false

        normalized = value.to_s.downcase
        return true if %w[true 1].include?(normalized)
        return false if %w[false 0].include?(normalized)

        raise DataTableValidationError, "Value '#{value}' does not match column type 'boolean'"
      end

      def normalize_date(value)
        time =
          case value
          when Time
            value
          when Date
            value.to_time
          else
            Time.zone.parse(value.to_s)
          end

        if time.nil?
          raise DataTableValidationError, "Value '#{value}' does not match column type 'date'"
        end

        time.utc
      rescue ArgumentError, TypeError
        raise DataTableValidationError, "Value '#{value}' does not match column type 'date'"
      end
    end
  end
end
