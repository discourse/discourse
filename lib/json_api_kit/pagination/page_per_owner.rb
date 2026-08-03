# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class PagePerOwner
      SplitOrder = Class.new(StandardError)

      def initialize(scope, order:, size:, owner_key:)
        @scope = scope
        @order = order
        @size = size
        @owner_key = owner_key
        verify_one_segment
      end

      def rows
        @rows ||=
          keyset
            .project(segment.scope(numbered_scope))
            .reorder(keyset.order)
            .map { Row.new(record: it, segment:) }
      end

      def next = nil

      def previous = nil

      private

      attr_reader :scope, :order, :size, :owner_key

      def segment = order.first

      def keyset = segment.keyset

      def numbered_scope = NumberedRows.new(scope, owner_key:, keyset:, size:).bounded_scope

      def verify_one_segment
        return unless order.split?
        raise SplitOrder,
              "a relationship is read one page for each owner, and #{order.leading.name} can " \
                "be null. Declare a default sort on a column that cannot be null."
      end
    end
  end
end
