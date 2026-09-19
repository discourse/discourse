# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Around
      def initialize(scope, order:, row:, before: 0, after: 0, include_row: true)
        @scope = scope
        @order = order
        @row = row
        @before = before
        @after = after
        @include_row = include_row
      end

      def rows = page_before.rows + anchor + page_after.rows

      def next = page_after.next

      def previous = page_before.previous

      private

      attr_reader :scope, :order, :row, :before, :after

      def include_row? = @include_row

      def anchor
        return [] unless include_row?
        [row]
      end

      def page_before
        @page_before ||= Paginator::Backwards.new(scope, order:, size: before, from: row.position)
      end

      def page_after
        @page_after ||= Paginator::Forwards.new(scope, order:, size: after, from: row.position)
      end
    end
  end
end
