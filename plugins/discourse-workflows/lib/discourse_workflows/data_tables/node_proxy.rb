# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class NodeProxy
      OPERATOR_MAP = {
        "equals" => "eq",
        "notEquals" => "neq",
        "contains" => "ilike",
        "notContains" => "not_ilike",
      }.freeze

      COMPOUND_OPERATORS = {
        "empty" => {
          "condition" => "eq",
          "value" => nil,
        },
        "notEmpty" => {
          "condition" => "neq",
          "value" => nil,
        },
        "true" => {
          "condition" => "eq",
          "value" => true,
        },
        "false" => {
          "condition" => "eq",
          "value" => false,
        },
      }.freeze

      def initialize(facade)
        @facade = facade
        @columns_resolver = Nodes::DataTable::ColumnsResolver.new(facade.data_table)
      end

      def data_table
        @facade.data_table
      end

      def facade
        @facade
      end

      def column_names
        @facade.data_table.columns.map { |c| c["name"] }
      end

      def insert(columns:)
        @facade.insert(build_row_input(columns))
      end

      def get(
        filter: nil,
        filter_combinator: "and",
        limit: nil,
        sort_column: nil,
        sort_direction: nil
      )
        query = build_query(filter:, filter_combinator:, limit:, sort_column:, sort_direction:)
        @facade.query(query)[:rows]
      end

      def update(filter: nil, filter_combinator: "and", columns: {})
        @facade.update(
          query: build_query(filter:, filter_combinator:),
          row_input: build_row_input(columns),
        )
      end

      def delete(filter: nil, filter_combinator: "and")
        @facade.delete(query: build_query(filter:, filter_combinator:))
      end

      def upsert(filter: nil, filter_combinator: "and", columns: {})
        row_input = build_row_input(columns)
        query = build_query(filter:, filter_combinator:)

        if query.normalized_filter.nil?
          { operation: "insert", row: @facade.insert(row_input) }
        else
          @facade.upsert(query:, row_input:)
        end
      end

      private

      def build_query(
        filter:,
        filter_combinator:,
        limit: nil,
        sort_column: nil,
        sort_direction: nil
      )
        normalized_filter =
          if filter.present?
            {
              "type" => filter_combinator || "and",
              "filters" => filter.map { |c| normalize_condition(c) },
            }
          end

        query =
          @facade.build_query(
            filter: normalized_filter,
            limit: limit,
            sort_by: resolve_sort_column(sort_column),
            sort_direction: sort_direction,
            optional_filter: true,
          )
        raise ArgumentError, query.errors.full_messages.join(", ") if query.invalid?
        query
      end

      def build_row_input(columns)
        row_input =
          @facade.build_row_input(
            data: @columns_resolver.resolve(columns || {}),
            fill_missing: false,
          )
        raise ArgumentError, row_input.errors.full_messages.join(", ") if row_input.invalid?
        row_input
      end

      def normalize_condition(condition)
        operator = condition["condition"]
        if (compound = COMPOUND_OPERATORS[operator])
          condition.merge(compound)
        elsif (mapped = OPERATOR_MAP[operator])
          condition.merge("condition" => mapped)
        else
          condition
        end
      end

      def resolve_sort_column(column_name)
        return if column_name.blank?
        @columns_resolver.validate_column!(column_name)
        column_name
      end
    end
  end
end
