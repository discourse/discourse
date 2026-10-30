# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Page
        class Requested
          class First < Requested
            def paginate(scope, order:, limits:, anchors: nil)
              Pagination::Paginator.for(scope, order:, size: limits.size(size))
            end
          end
        end
      end
    end
  end
end
