# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Pagination
        class Paginator
          class Forwards < Paginator
            def next = page_ahead

            def previous = page_behind
          end
        end
      end
    end
  end
end
