# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Pagination
        class Order
          class Position
            attr_reader :segment, :values

            def self.from(cursor, order:)
              digest, segment_id, *values = cursor.values
              unless digest == order.digest
                raise ArgumentError, "Cursor does not match the requested resource and sort order."
              end
              new(segment: order.fetch(segment_id), values:)
            end

            def initialize(segment:, values:)
              unless segment.compatible_with?(values)
                raise ArgumentError,
                      "Incorrect number of values for this order segment: " \
                        "expected #{segment.keyset.keys.size}, received #{values.size}."
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
  end
end
