# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow
    MAX_CELL_LENGTH = 50_000

    module ColumnNormalizer
      class Number
        def normalize(value)
          return nil if value.nil?
          return nil if value == ""

          if value.is_a?(Numeric)
            raise ArgumentError, "Value '#{value}' is not a finite number" unless value.finite?
            return value
          end

          value.to_s.match?(/\A-?\d+\z/) ? Integer(value, 10) : Float(value)
        rescue ArgumentError, TypeError
          raise ArgumentError, "Value '#{value}' does not match column type 'number'"
        end
      end

      class Boolean
        def normalize(value)
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
      end

      class Date
        def normalize(value)
          return nil if value.nil?
          return nil if value == ""

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
      end

      class Text
        def normalize(value)
          return nil if value.nil?

          str = value.to_s
          if str.length > MAX_CELL_LENGTH
            raise ArgumentError,
                  "Value exceeds maximum cell length of #{MAX_CELL_LENGTH} characters"
          end
          str
        end
      end

      REGISTRY = {
        "number" => Number.new,
        "boolean" => Boolean.new,
        "date" => Date.new,
        "string" => Text.new,
      }.freeze

      def self.for(type)
        REGISTRY.fetch(type.to_s) { REGISTRY.fetch("string") }
      end
    end

    class << self
      def column_map(data_table)
        data_table
          .columns
          .reject do |column|
            DataTableStorage::RESERVED_COLUMN_NAMES.include?(DataTable.column_name(column))
          end
          .index_by { |column| DataTable.column_name(column) }
      end

      def normalize_row_data(data_table, data, fill_missing:)
        raise ArgumentError, "Row data must be an object" unless data.is_a?(Hash)

        normalized_data = data.stringify_keys
        columns = column_map(data_table)
        unknown_columns = normalized_data.keys - columns.keys

        if unknown_columns.any?
          raise ArgumentError, "Unknown column name '#{unknown_columns.first}'"
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
        ColumnNormalizer.for(type).normalize(value)
      end
    end
  end
end
