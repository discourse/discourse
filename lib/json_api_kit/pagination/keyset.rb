# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # A total order over a scope, held as an ordered set of keys: which columns or
    # expressions, which directions, which joins, which of them nullable. Keyset
    # pagination compares rows against this order, and a cursor carries one value per
    # key of it.
    class Keyset
      attr_reader :keys

      def initialize(keys)
        @keys = keys.flat_map(&:expand).uniq(&:name)
        raise ArgumentError, "an order needs at least one key" if @keys.empty?
      end

      def order = keys.to_h { [it.name, it.direction] }

      def joins = keys.flat_map(&:joins).uniq

      def reverse = self.class.new(keys.map(&:reverse))

      def cursor_for(record) = Cursor.new(keys.map { it.value_for(record) })

      # Every keyset value has to be readable as a column of the scope — that is what
      # lets ordering, comparison and cursor minting treat SQL-backed keys and null
      # flags exactly like columns. One subquery selects all of them.
      def project(scope)
        projections = keys.filter_map(&:select_expression)
        return scope if projections.empty?

        model = scope.klass
        inner = scope.joins(joins).select(model.arel_table[Arel.star], *projections)
        model.select(Arel.star).from(inner, model.table_name)
      end
    end
  end
end
