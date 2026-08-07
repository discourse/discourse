# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # The comparison selecting the rows that follow a cursor's position in a keyset
    # order, against the relation that order has been projected onto.
    #
    # Only "after" exists: reading backwards reverses the keyset rather than inverting
    # the comparison, so there is one shape to get right instead of two.
    #
    # Cursor values reach us from a client, so they are always bound. The only literal
    # text here is what a resource authored: a key's name and its SQL.
    class Predicate
      def initialize(keyset, cursor)
        raise ArgumentError, "a split order is read one band at a time" if keyset.splits?

        @terms = keyset.keys.zip(cursor.values).map { Term.for(*it) }
        raise Cursor::Invalid, "this order needs #{terms.size} values" if terms.size != cursor.size
      end

      def sql
        return row_wise_comparison if row_wise?
        hinted(disjuncts.join(" OR "))
      end

      def bindings = terms.map(&:bindings).reduce({}, :merge)

      # The relation has to be one the keyset was projected onto, since that is where the
      # keys are readable as columns.
      def apply(scope) = scope.where(sql, bindings)

      private

      attr_reader :terms

      # Row-wise comparison is the form an index seeks on directly, but it evaluates to
      # NULL — dropping every row — as soon as one element is NULL, so it is only available
      # where no key holds a null the comparison has to take in, and it can only carry a
      # single direction.
      def row_wise?
        terms.many? && terms.all?(&:comparable?) && terms.map(&:operator).uniq.one?
      end

      def row_wise_comparison
        "(#{terms.map(&:identifier).join(", ")}) #{leading.operator} " \
          "(#{terms.map(&:placeholder).join(", ")})"
      end

      # Every prefix of the order contributes a disjunct: the keys before the prefix's last
      # one matched the cursor, and that last one moved past it.
      def disjuncts
        prefixes.reverse_each.flat_map do |prefix|
          *matched, moved = prefix
          moved.disjuncts(matched)
        end
      end

      def prefixes = 1.upto(terms.size).map { terms.first(it) }

      def hinted(comparison)
        return comparison if terms.one?
        leading.bound_on(comparison)
      end

      # The key an index seeks on first, and so the one worth bounding.
      def leading = terms.first
    end
  end
end
