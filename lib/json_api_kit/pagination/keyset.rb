# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Keyset
      attr_reader :keys

      delegate :valued_condition, :null_condition, :nulls_read_first?, to: :leading

      def initialize(keys)
        @keys = keys.uniq(&:name)
        raise ArgumentError, "an order needs at least one key" if @keys.empty?
      end

      def leading = keys.first

      def rest = self.class.new(keys.drop(1))

      def split? = leading.nullable?

      def without_nulls = self.class.new([leading.without_nulls, *keys.drop(1)])

      def columns = keys.reject(&:projected?).map(&:name)

      def order = keys.map(&:ordering)

      def joins = keys.map(&:joins).reduce(:+)

      def reverse = self.class.new(keys.map(&:reverse))

      def values_for(record) = keys.map { Cursor.coerce(it.value_for(record)) }

      def compatible_with?(values) = values.size == keys.size

      def project(scope)
        return scope if projections.empty?

        model = scope.klass
        model.unscoped.select(Arel.star).from(subquery(scope), model.table_name)
      end

      private

      def subquery(scope)
        selection = scope.select_values.presence || [scope.klass.arel_table[Arel.star]]
        joins.apply(scope).reselect(*selection, *projections)
      end

      def projections = @projections ||= keys.filter_map(&:select_expression)
    end
  end
end
