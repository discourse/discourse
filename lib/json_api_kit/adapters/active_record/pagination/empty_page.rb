# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Pagination
        class EmptyPage
          def rows = []

          def next = nil

          def previous = nil
        end
      end
    end
  end
end
