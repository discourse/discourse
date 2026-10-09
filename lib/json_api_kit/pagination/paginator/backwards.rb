# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Paginator
      class Backwards < Paginator
        def rows = super.reverse

        def next = page_behind

        def previous = page_ahead

        private

        def page_order = @page_order ||= order.reverse
      end
    end
  end
end
