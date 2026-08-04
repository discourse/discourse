# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # One page of rows read along a keyset order, and whether the order carries on past
    # them.
    #
    # It only ever reads forwards: a page read backwards is a window over the reversed
    # keyset, which the caller turns back into presentation order. A window of no rows is
    # the probe form — it reads nothing, and answers whether anything lies that way.
    class Window
      def initialize(scope, keyset:, size:, after: nil)
        @scope = scope
        @keyset = keyset
        @size = size
        @after = after
      end

      def records = read.first(size)

      # Whether the order carries on past the page. One row beyond it is read to answer
      # this, so it costs nothing more than the page itself.
      def truncated? = read.size > size

      private

      attr_reader :scope, :keyset, :size, :after

      def read = @read ||= page.to_a

      def page
        return ordered if after.nil?
        Predicate.new(keyset, after).apply(ordered)
      end

      # The order itself, asked for one row beyond the page so the window knows whether it
      # was truncated.
      def ordered = keyset.project(scope).reorder(keyset.order).limit(size + 1)
    end
  end
end
