# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Pagination
        class Window
          def initialize(scope, order:, size:, after: nil)
            @scope = scope
            @order = order
            @size = size
            @after = after
          end

          def rows = @rows ||= scans.flat_map(&:rows)

          def truncated? = scans.last.truncated?

          private

          attr_reader :scope, :order, :size, :after

          def scans
            @scans ||= Enumerator.produce(first_scan) { it.next_in(order) }.take_while { it }
          end

          def first_scan = Scan.new(scope, segment: starting_segment, size:, after: after&.values)

          def starting_segment = after&.segment || order.first
        end
      end
    end
  end
end
