# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module DataTable
      class ColumnsResolver
        def initialize(data_table)
          @column_names = data_table.columns.map { |c| c["name"] }.to_set
        end

        def resolve(fields)
          normalize_fields(fields).each_with_object({}) do |(column_name, value), result|
            if @column_names.exclude?(column_name)
              raise ArgumentError, "Unknown column name '#{column_name}'"
            end

            result[column_name] = value
          end
        end

        private

        def normalize_fields(fields)
          case fields
          when Hash
            fields.stringify_keys
          when Array
            fields.each_with_object({}) do |field, hash|
              field = field.with_indifferent_access
              hash[field[:columnName]] = field[:value]
            end
          else
            {}
          end
        end
      end
    end
  end
end
