# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # A page centred on one row of a listing: the rows before it, the row itself, and the rows
    # after it. It is how a client enters a listing at a place rather than at its start — a
    # permalink into a long listing, or an entry point such as the first unread row.
    #
    # It is the two ordinary readings, one each way from the row's position. Each side answers
    # for its own link and neither has to probe, since both read the direction they point in.
    class Around
      def initialize(scope, order:, row:, before: 0, after: 0, include_row: true)
        @scope = scope
        @order = order
        @row = row
        @before = before
        @after = after
        @include_row = include_row
      end

      def rows = preceding.rows + anchor + following.rows

      def records = rows.map(&:record)

      def next = following.next

      def previous = preceding.previous

      private

      attr_reader :scope, :order, :row, :before, :after

      def include_row? = @include_row

      # The anchor row itself, unless the client asked for its neighbours alone.
      def anchor
        return [] unless include_row?
        [row]
      end

      def preceding
        @preceding ||= Paginator::Backwards.new(scope, order:, size: before, from: row.position)
      end

      def following
        @following ||= Paginator::Forwards.new(scope, order:, size: after, from: row.position)
      end
    end
  end
end
