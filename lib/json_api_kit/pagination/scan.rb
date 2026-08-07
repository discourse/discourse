# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # One page-read inside a single segment of an order: the rows, and whether the segment
    # carries on past them.
    #
    # It reads one row beyond the page to answer that, and hands back rows rather than bare
    # records, since it knows the segment each one sits in. A scan of no rows is the probe
    # form — it reads nothing and answers only whether the segment holds anything.
    class Scan
      def initialize(scope, segment:, size:, after: nil)
        @scope = scope
        @segment = segment
        @size = size
        @after = after
      end

      def rows = read.first(size).map { Row.new(record: it, segment:) }

      def truncated? = read.size > size

      private

      attr_reader :scope, :segment, :size, :after

      def keyset = segment.keyset

      def read = @read ||= page.to_a

      def page
        return ordered unless after
        Predicate.new(keyset, after).apply(ordered)
      end

      # The segment's rows in its own order, asked for one beyond the page.
      def ordered = held.reorder(keyset.order).limit(size + 1)

      # The rows the segment holds, with every keyset value readable as a column of them.
      def held = keyset.project(segment.scope(scope))
    end
  end
end
