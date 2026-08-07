# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      # One band of a listing: the rows that belong to it, and the order they are read in
      # within it. A segment is identified rather than positioned, because a cursor names the
      # segment it was minted in and has to keep naming it when the listing is read backwards.
      class Segment
        # A segment holds every row it is offered unless it is given a condition.
        ALL_ROWS = ->(scope) { scope }

        # The bands a keyset reads a listing in: one segment where nothing splits it, and
        # otherwise the rows its leading key has values in, plus the band the rows it is null in
        # form — read again the same way, so an order leading with two nullable keys has three.
        #
        # Which band comes first is where that key's nulls sort. An id names a band; it does not
        # number the sequence.
        def self.split(keyset, id: 0)
          return [new(id:, keyset:)] unless keyset.splits?

          valued = new(id:, keyset: keyset.valued, rows: keyset.valued_rows)
          nulls = split(keyset.rest, id: id + 1).map { it.narrowed_by(keyset.null_rows) }
          keyset.nulls_read_first? ? [*nulls, valued] : [valued, *nulls]
        end

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
        # condition keeps of the ones it held already. Its identity does not change, since a
        # cursor names it.
        def narrowed_by(condition) = self.class.new(id:, keyset:, rows: rows_within(condition))

        private

        attr_reader :rows

        # This segment's rows, taken from those the given condition keeps.
        def rows_within(condition) = ->(scope) { rows.call(condition.call(scope)) }
      end
    end
  end
end
