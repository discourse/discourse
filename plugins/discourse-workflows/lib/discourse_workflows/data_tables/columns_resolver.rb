# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class ColumnsResolver
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
        case fields
        when Hash
          fields.stringify_keys
        when Array
          fields.to_h do |field|
            field = field.with_indifferent_access
            [field[:columnName], field[:value]]
          end
        else
          {}
        end
      end
    end
  end
end
