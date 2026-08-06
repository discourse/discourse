# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # The comparison order inside one segment of a listing: which columns or expressions,
    # which directions, which joins, which of them nullable. Keyset pagination compares
    # rows against this order, and a cursor carries one value per key of it.
    #
    # A nullable key is a key like any other until it is compared, where the rows it is null
    # in have to be taken in rather than compared (see Predicate). A listing whose *leading*
    # key is nullable is split into segments instead (see Order), because a query that reaches
    # the null tail cannot bound the column the tail is null in.
    class Keyset
      attr_reader :keys

      def initialize(keys)
        @keys = keys.uniq(&:name)
        raise ArgumentError, "an order needs at least one key" if @keys.empty?
      end

      # The key an index seeks on first, and so the one a listing is segmented at when it can
      # be null.
      def leading = keys.first

      # The order behind the leading key. A nullable leading key must have one: the rows its
      # value is null in are ordered by nothing else, and a page needs a total order.
      def rest = self.class.new(keys.drop(1))

      # Whether the listing this order reads is split into bands: it is when the leading key can
      # be null, the rows it is null in belonging to a band of their own (see Order). Only an
      # order that does not split can be compared, a bound on a nullable key being no bound.
      def splits? = leading.nullable?

      # This order as the band where its leading key has values reads it: nulls cannot appear
      # there, so that key names no placement.
      def valued = self.class.new([leading.without_nulls, *keys.drop(1)])

      def order = keys.map(&:ordering)

      def joins = keys.flat_map(&:joins).uniq

      def reverse = self.class.new(keys.map(&:reverse))

      # Where a row sits in this order: one value per key, in the order's own sequence.
      def cursor_for(record) = Cursor.new(values_for(record))

      # Every keyset value has to be readable as a column of the scope — that is what lets
      # ordering, comparison and cursor minting treat a key backed by SQL exactly like a
      # column. One subquery selects all of them.
      def project(scope)
        return scope if projections.empty?

        model = scope.klass
        inner = scope.joins(joins).select(model.arel_table[Arel.star], *projections)
        model.select(Arel.star).from(inner, model.table_name)
      end

      private

      def values_for(record) = keys.map { it.value_for(record) }

      # The keys the table cannot hand over as columns of its own, each selected under the name
      # the order knows it by.
      def projections = @projections ||= keys.filter_map(&:select_expression)
    end
  end
end
