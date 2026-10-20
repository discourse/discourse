# frozen_string_literal: true

module JsonApiKit
  module Page
    class Requested
      class After < Requested
        def initialize(cursor, size: nil)
          super(size:)
          @cursor = cursor
        end

        def paginate(scope, order:, limits:, anchors: nil)
          Pagination::Paginator.for(scope, order:, size: limits.size(size), after: cursor)
        end

        private

        attr_reader :cursor
      end
    end
  end
end
