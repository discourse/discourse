# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow
    MAX_CELL_LENGTH = 10_000

    class << self
      def column_map(data_table)
        data_table
          .columns
          .index_by { |column| DataTable.column_name(column) }
          .except(*DataTables::Types::SYSTEM_COLUMN_NAMES)
      end

      def normalize_row_data(data_table, data, fill_missing:)
        raise ArgumentError, "Row data must be an object" unless data.is_a?(Hash)

        normalized_data = data.stringify_keys
        columns = column_map(data_table)
        unknown_column = normalized_data.keys.find { |name| !columns.key?(name) }
        raise ArgumentError, "Unknown column name '#{unknown_column}'" if unknown_column

        values =
          fill_missing ? columns.keys.index_with { |name| normalized_data[name] } : normalized_data
        values.each_with_object({}) do |(name, value), result|
          result[name] = normalize_value(
            value,
            DiscourseWorkflows::DataTable.column_type(columns.fetch(name)),
          )
        end
      end

      def normalize_value(value, type)
        case type.to_s
        when "number"
          normalize_number(value)
        when "boolean"
          normalize_boolean(value)
        when "date"
          normalize_date(value)
        else
          normalize_text(value)
        end
      end

      private

      def normalize_number(value)
        return nil if value.nil? || value == ""

        if value.is_a?(Numeric)
          raise ArgumentError, "Value '#{value}' is not a finite number" unless value.finite?
          return value
        end

        value.to_s.match?(/\A-?\d+\z/) ? Integer(value, 10) : Float(value)
      rescue ArgumentError, TypeError
        raise ArgumentError, "Value '#{value}' does not match column type 'number'"
      end

      def normalize_boolean(value)
        return nil if value.nil?
        return value if value.in?([true, false])

        case value.to_s.downcase
        when "true", "1"
          true
        when "false", "0"
          false
        else
          raise ArgumentError, "Value '#{value}' does not match column type 'boolean'"
        end
      end

      def normalize_date(value)
        return nil if value.nil? || value == ""

        time =
          case value
          when Time
            value
          when ::Date
            value.to_time
          else
            Time.zone.parse(value.to_s)
          end

        raise ArgumentError, "Value '#{value}' does not match column type 'date'" if time.nil?

        time.utc
      rescue ArgumentError, TypeError
        raise ArgumentError, "Value '#{value}' does not match column type 'date'"
      end

      def normalize_text(value)
        return nil if value.nil?

        str = value.to_s
        if str.length > MAX_CELL_LENGTH
          raise ArgumentError, "Value exceeds maximum cell length of #{MAX_CELL_LENGTH} characters"
        end
        str
      end
    end
  end
end
