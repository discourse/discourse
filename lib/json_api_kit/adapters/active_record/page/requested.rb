# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Page
        class Requested
          class << self
            def from(request, adapter:)
              self.for(
                **request.page.except(:item_cursors, :anchor).compact,
                after: request.page[:after].try { adapter.parse_cursor(it) },
                before: request.page[:before].try { adapter.parse_cursor(it) },
                anchoring: request.anchoring,
              )
            end

            def for(size: nil, after: nil, before: nil, anchoring: nil, **window)
              return Around.new(anchoring, size:, **window) if anchoring
              return After.new(after, size:) if after
              return Before.new(before, size:) if before
              First.new(size:)
            end
          end

          def initialize(size: nil)
            @size = size
          end

          private

          attr_reader :size
        end
      end
    end
  end
end
