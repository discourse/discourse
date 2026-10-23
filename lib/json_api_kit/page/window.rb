# frozen_string_literal: true

module JsonApiKit
  module Page
    class Window
      def initialize(page_size:, before: nil, after: nil, include_anchor: true)
        @include_anchor = include_anchor
        @before = before.to_i
        @after = after || (before ? 0 : page_size - anchor_rows)
      end

      attr_reader :before, :after

      def paginate(scope, order:, row:)
        Pagination::Around.new(scope, order:, row:, before:, after:, include_row: include_anchor?)
      end

      private

      def include_anchor? = @include_anchor

      def anchor_rows = include_anchor? ? 1 : 0
    end
  end
end
