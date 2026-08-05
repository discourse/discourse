# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      # One band of a listing: the rows that belong to it, and the order they are read in
      # within it. A segment is identified rather than positioned, because a cursor names the
      # segment it was minted in and has to keep naming it when the listing is read backwards.
      class Segment
        # A segment holds every row it is offered unless it is given a narrowing.
        ALL_ROWS = ->(scope) { scope }

        attr_reader :id, :keyset

        # `rows` narrows a scope to this segment's members.
        def initialize(id:, keyset:, rows: ALL_ROWS)
          @id = id
          @keyset = keyset
          @rows = rows
        end

        def scope(scope) = rows.call(scope)

        # Where a row of this segment sits in the listing.
        def position_of(record) = Position.new(segment: self, cursor: keyset.cursor_for(record))

        def reverse = self.class.new(id:, keyset: keyset.reverse, rows:)

        # The same segment of the listing, narrowed further: it holds the rows the given
        # narrowing keeps of the ones it held already. Its identity does not change, since a
        # cursor names it.
        def narrowed_by(narrowing) = self.class.new(id:, keyset:, rows: rows_within(narrowing))

        private

        attr_reader :rows

        # This segment's rows, taken from those the given narrowing keeps.
        def rows_within(narrowing) = ->(scope) { rows.call(narrowing.call(scope)) }
      end
    end
  end
end
