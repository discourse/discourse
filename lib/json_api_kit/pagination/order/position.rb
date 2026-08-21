# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      class Position
        attr_reader :segment, :cursor

        def self.from(cursor, order:)
          id, *values = cursor.values
          new(segment: order.fetch(id), cursor: Cursor.new(values))
        end

        def initialize(segment:, cursor:)
          unless segment.compatible_with?(cursor:)
            raise ArgumentError, "a cursor holds one value for each key its segment compares"
          end

          @segment = segment
          @cursor = cursor
        end

        def to_cursor = Cursor.new([segment.id, *cursor.values])

        def in(order) = order.position(to_cursor)
      end
    end
  end
end
