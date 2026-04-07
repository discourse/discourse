# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module DataTable
      class FilterResolver
        OPERATOR_MAP = {
          "equals" => "eq",
          "notEquals" => "neq",
          "gt" => "gt",
          "lt" => "lt",
          "gte" => "gte",
          "lte" => "lte",
          "contains" => "ilike",
          "notContains" => "not_ilike",
        }.freeze

        def initialize(data_table)
          @data_table = data_table
          @column_names = data_table.columns.map { |c| c["name"] }.to_set
        end

        def resolve(config)
          raw_filter = build_filter(config)
          return if raw_filter.nil?

          normalized =
            DiscourseWorkflows::NormalizedFilter.new(data_table: @data_table, filter: raw_filter)
          raise ArgumentError, normalized.errors.full_messages.join(", ") if normalized.invalid?

          normalized.value
        end

        def resolve_sort_column_name(column_name)
          return if column_name.blank?

          if @column_names.exclude?(column_name)
            raise ArgumentError, "Unknown column name '#{column_name}'"
          end

          column_name
        end

        private

        def build_filter(config)
          conditions = config["filter"]
          return nil if conditions.blank?

          {
            "type" => config.fetch("filter_combinator") { "and" },
            "filters" => conditions.map { |c| resolve_condition(c) },
          }
        end

        def resolve_condition(condition)
          column_name = condition["leftValue"]
          operation = condition.dig("operator", "operation")

          if @column_names.exclude?(column_name)
            raise ArgumentError, "Unknown column name '#{column_name}'"
          end

          mapped = map_operation(operation, condition["rightValue"])

          {
            "columnName" => column_name,
            "condition" => mapped[:condition],
            "value" => mapped[:value],
          }
        end

        def map_operation(operation, right_value)
          case operation
          when "empty"
            { condition: "eq", value: nil }
          when "notEmpty"
            { condition: "neq", value: nil }
          when "true"
            { condition: "eq", value: true }
          when "false"
            { condition: "eq", value: false }
          else
            condition =
              OPERATOR_MAP[operation] || raise(ArgumentError, "Unsupported operator '#{operation}'")
            { condition: condition, value: right_value }
          end
        end
      end
    end
  end
end
