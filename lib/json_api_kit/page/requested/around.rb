# frozen_string_literal: true

module JsonApiKit
  module Page
    class Requested
      class Around < Requested
        def initialize(
          anchoring,
          size: nil,
          before_size: nil,
          after_size: nil,
          include_anchor: true
        )
          super(size:)
          @anchoring = anchoring
          @before_size = before_size
          @after_size = after_size
          @include_anchor = include_anchor
        end

        def paginate(scope, order:, limits:, anchors:)
          row = anchors.locate(anchoring, scope:, order:)
          return window(limits).paginate(scope, order:, row:) if row
          return Pagination::EmptyPage.new unless anchoring.computed?
          First.new(size:).paginate(scope, order:, limits:)
        end

        private

        attr_reader :anchoring, :before_size, :after_size

        def window(limits)
          Window.new(
            page_size: limits.size(size),
            before: before_size,
            after: after_size,
            include_anchor: @include_anchor,
          )
        end
      end
    end
  end
end
