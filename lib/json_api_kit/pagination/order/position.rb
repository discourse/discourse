# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      class Position
        attr_reader :segment, :values

        class << self
          def from(cursor, order:)
            digest, segment_id, *values = cursor.values
            unless digest == order.digest
              raise ArgumentError, "a cursor comes from one resource and one sort"
            end
            new(segment: order.fetch(segment_id), values:)
          end
        end

        def initialize(segment:, values:)
          unless segment.compatible_with?(values)
            raise ArgumentError, "a position holds one value for each key its segment compares"
          end

          @segment = segment
          @values = values
        end

        def to_cursor = Cursor.new([segment.digest, segment.id, *values])

        def in(order) = order.position(to_cursor)
      end
    end
  end
end
