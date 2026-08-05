# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # One page of rows read along an order, and whether the order carries on past them.
    #
    # An order is read one segment at a time, so a page that runs out of rows in the segment
    # it started in spills into the segment after it — which is what keeps every read
    # bounded, and therefore seekable. A page that ends exactly where a segment does still
    # asks the next one whether anything is there.
    #
    # It reads forwards only: a page read backwards is a window over the reversed order,
    # which the caller turns back into presentation order. A window of no rows is the probe
    # form — it reads nothing, and answers whether anything lies that way at all.
    #
    # `after` is a position, not a cursor: cursors belong to the wire, and by the time a page
    # is being read the segment it starts in has already been resolved.
    class Window
      def initialize(scope, order:, size:, after: nil)
        @scope = scope
        @order = order
        @size = size
        @after = after
      end

      def rows = scans.flat_map(&:rows)

      def records = rows.map(&:record)

      def truncated? = scans.last.truncated?

      private

      attr_reader :scope, :order, :size, :after

      def scans = @scans ||= read_from(starting_segment, size:, after: after&.cursor)

      # A page is one segment read, and — when that segment ran out before the page was full
      # and another follows it — the same page carried on from the start of the next.
      def read_from(segment, size:, after:)
        scan = Scan.new(scope, segment:, size:, after:)
        return [scan] if scan.truncated?

        following = order.after(segment)
        return [scan] if following.nil?
        [scan, *read_from(following, size: size - scan.rows.size, after: nil)]
      end

      def starting_segment = after&.segment || order.first
    end
  end
end
