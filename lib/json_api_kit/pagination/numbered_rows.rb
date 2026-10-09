# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class NumberedRows
      ROW_NUMBER = "json_api_kit_row_number"

      def initialize(scope, owner_key:, keyset:, size:)
        @scope = scope
        @owner_key = owner_key
        @keyset = keyset
        @size = size
      end

      def bounded_scope
        scope
          .model
          .unscoped
          .from(numbered_scope, table_name)
          .where(row_number.lteq(size + 1))
          .select(*selected_columns)
      end

      private

      attr_reader :scope, :owner_key, :keyset, :size

      def numbered_scope = scope.reselect(*selected_columns, number_rows)

      def selected_columns
        @selected_columns ||=
          scope.select_values.presence || scope.model.column_names.map { column(it) }
      end

      def number_rows
        Arel::Nodes::NamedFunction.new("ROW_NUMBER", []).over(window).as(ROW_NUMBER)
      end

      def window = Arel::Nodes::Window.new.partition(column(owner_key)).order(keyset.order)

      def row_number = Arel::Table.new(table_name)[ROW_NUMBER]

      def column(name) = scope.arel_table[name]

      def table_name = scope.arel_table.name
    end
  end
end
