# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Pagination
        class Scan
          def initialize(scope, segment:, size:, after: nil)
            @scope = scope
            @segment = segment
            @size = size
            @after = after
          end

          def rows = @rows ||= records.first(size).map { Row.new(record: it, segment:) }

          def truncated? = records.size > size

          def next_in(order)
            return if truncated?

            order
              .after(segment)
              .first
              .try { self.class.new(scope, segment: it, size: size - rows.size) }
          end

          private

          attr_reader :scope, :segment, :size, :after

          def keyset = segment.keyset

          def records = @records ||= page_scope.to_a

          def page_scope
            return ordered_scope unless after
            Predicate.new(keyset, after).apply(ordered_scope)
          end

          def ordered_scope = held_scope.reorder(keyset.order).limit(size + 1)

          def held_scope = keyset.project(segment.scope(scope))
        end
      end
    end
  end
end
