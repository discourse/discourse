# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class ColumnsResolver
      # Returns column name => value pairs, or nil when the value isn't keyed by
      # column (e.g. an unresolved whole-object expression).
      def self.column_pairs(fields)
        case fields
        when nil
          {}
        when Hash
          fields.stringify_keys
        when Array
          fields = fields.map { |field| field.try(:with_indifferent_access) }
          return unless fields.all? { |field| field&.key?(:columnName) }

          fields.to_h { |field| [field[:columnName], field[:value]] }
        end
      end

      def initialize(data_table)
        @column_names =
          data_table
            .columns
            .filter_map do |column|
              name = DiscourseWorkflows::DataTable.column_name(column)
              name unless Types.system_column?(name)
            end
            .to_set
      end

      def resolve(fields)
        normalize_fields(fields).each_with_object({}) do |(column_name, value), result|
          validate_column!(column_name)
          result[column_name] = value
        end
      end

      def validate_column!(column_name)
        return if @column_names.include?(column_name)

        raise ArgumentError,
              I18n.t("discourse_workflows.errors.data_table.unknown_column", column: column_name)
      end

      private

      def normalize_fields(fields)
        self.class.column_pairs(fields) || raise_invalid_columns!(fields)
      end

      def raise_invalid_columns!(fields)
        raise ArgumentError,
              I18n.t(
                "discourse_workflows.errors.data_table.invalid_columns",
                value: fields.to_s.truncate(100),
              )
      end
    end
  end
end
