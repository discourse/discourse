# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      class Segment
        NO_CONDITION = ->(scope) { scope }

        class << self
          def split(keyset, digest: nil, id: 0)
            return [new(id:, keyset:, digest:)] unless keyset.split?

            valued =
              new(id:, keyset: keyset.without_nulls, digest:, condition: keyset.valued_condition)
            nulls =
              split(keyset.rest, digest:, id: id + 1).map { it.narrowed_by(keyset.null_condition) }
            keyset.nulls_read_first? ? [*nulls, valued] : [valued, *nulls]
          end
        end

        attr_reader :id, :keyset, :digest

        delegate :columns, :compatible_with?, to: :keyset

        def initialize(id:, keyset:, digest: nil, condition: NO_CONDITION)
          @id = id
          @keyset = keyset
          @digest = digest
          @condition = condition
        end

        def scope(scope) = condition.call(scope)

        def position_of(record) = Position.new(segment: self, values: keyset.values_for(record))

        def led_by?(name) = keyset.leading.named?(name)

        def reverse = self.class.new(id:, keyset: keyset.reverse, digest:, condition:)

        def narrowed_by(other) =
          self.class.new(id:, keyset:, digest:, condition: condition_after(other))

        private

        attr_reader :condition

        def condition_after(other) = ->(scope) { condition.call(other.call(scope)) }
      end
    end
  end
end
