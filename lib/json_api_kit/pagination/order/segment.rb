# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      class Segment
        NO_CONDITION = ->(scope) { scope }

        def self.split(keyset, id: 0)
          return [new(id:, keyset:)] unless keyset.split?

          valued = new(id:, keyset: keyset.without_nulls, condition: keyset.valued_condition)
          nulls = split(keyset.rest, id: id + 1).map { it.narrowed_by(keyset.null_condition) }
          keyset.nulls_read_first? ? [*nulls, valued] : [valued, *nulls]
        end

        attr_reader :id, :keyset

        delegate :columns, :compatible_with?, to: :keyset

        def initialize(id:, keyset:, condition: NO_CONDITION)
          @id = id
          @keyset = keyset
          @condition = condition
        end

        def scope(scope) = condition.call(scope)

        def position_of(record) = Position.new(segment: self, cursor: keyset.cursor_for(record))

        def led_by?(name) = keyset.leading.named?(name)

        def reverse = self.class.new(id:, keyset: keyset.reverse, condition:)

        def narrowed_by(other) = self.class.new(id:, keyset:, condition: condition_after(other))

        private

        attr_reader :condition

        def condition_after(other) = ->(scope) { condition.call(other.call(scope)) }
      end
    end
  end
end
