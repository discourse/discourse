# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      # Where a cursor points: the segment it was minted in, and the values its place within
      # that segment is compared against.
      #
      # On the wire a cursor is that segment's id followed by those values, and this is the
      # only place that shape is written or read.
      class Position
        attr_reader :segment, :cursor

        def self.from(cursor, order:)
          id, *values = cursor.values
          new(segment: order.segment(id), cursor: Cursor.new(values))
        end

        def initialize(segment:, cursor:)
          @segment = segment
          @cursor = cursor
        end

        def to_cursor = Cursor.new([segment.id, *cursor.values])

        # The same place, as another reading of the listing names it. A reversed order holds
        # the same segments, but each with its keyset walked the other way, so a position has
        # to be resolved against the order that will read it.
        def in(order) = order.position(to_cursor)
      end
    end
  end
end
