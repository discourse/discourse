# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Paginator
      # A page read forwards along the order, which is how a listing is read unless a client
      # asks otherwise. The window answers for the page ahead; the page behind is probed.
      class Forwards < Paginator
        def next = further

        def previous = behind
      end
    end
  end
end
