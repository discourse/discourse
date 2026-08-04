# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Paginator
      # A page read backwards from a cursor, for a client walking towards the start of a
      # listing. The order is walked in reverse, so the rows come back last-first and are
      # turned round to be presented; the window then answers for the page behind, and the
      # page ahead is the one that takes a probe.
      class Backwards < Paginator
        def records = super.reverse

        def next = behind

        def previous = further

        private

        def reading = keyset.reverse
      end
    end
  end
end
