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

      def joins = keys.flat_map(&:joins).uniq

      def reverse = self.class.new(keys.map(&:reverse))

      def cursor_for(record) = Cursor.new(values_for(record))

      def compatible_with?(cursor:) = cursor.size == keys.size

      def project(scope)
        return scope if projections.empty?

        model = scope.klass
        inner = scope.joins(joins).select(model.arel_table[Arel.star], *projections)
        model.select(Arel.star).from(inner, model.table_name)
      end

      private

      def values_for(record) = keys.map { it.value_for(record) }

      def projections = @projections ||= keys.filter_map(&:select_expression)
    end
  end
end
