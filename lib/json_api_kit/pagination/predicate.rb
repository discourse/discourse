# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Predicate
      def initialize(keyset, cursor)
        raise ArgumentError, "a split order is read one segment at a time" if keyset.split?

        @terms = keyset.keys.zip(cursor.values).map { Term.for(*it) }
      end

      def sql
        return row_wise_comparison if row_wise?
        bound_by_leading_key(disjuncts.join(" OR "))
      end

      def bindings = terms.map(&:bindings).reduce({}, :merge)

      def apply(scope) = scope.where(sql, bindings)

      private

      attr_reader :terms

      def row_wise?
        terms.many? && terms.all?(&:comparable?) && terms.map(&:operator).uniq.one?
      end

      def row_wise_comparison
        "(#{terms.map(&:identifier).join(", ")}) #{leading.operator} " \
          "(#{terms.map(&:placeholder).join(", ")})"
      end

      def disjuncts
        prefixes.reverse_each.flat_map do |prefix|
          *matched, moved = prefix
          moved.disjuncts(matched)
        end
      end

      def prefixes = 1.upto(terms.size).map { terms.first(it) }

      def bound_by_leading_key(comparison)
        return comparison if terms.one?
        leading.bound_on(comparison)
      end

      def leading = terms.first
    end
  end
end
