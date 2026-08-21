# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Window
      def initialize(scope, order:, size:, after: nil)
        @scope = scope
        @order = order
        @size = size
        @after = after
      end

      def rows = scans.flat_map(&:rows)

      def truncated? = scans.last.truncated?

      private

      attr_reader :scope, :order, :size, :after

      def scans = @scans ||= read_from(starting_segment, size:, after: after&.cursor)

      def read_from(segment, size:, after:)
        scan = Scan.new(scope, segment:, size:, after:)
        return [scan] if scan.truncated?

        segment_after = order.after(segment).first
        return [scan] unless segment_after
        [scan, *read_from(segment_after, size: size - scan.rows.size, after: nil)]
      end

      def starting_segment = after&.segment || order.first
    end
  end
end
