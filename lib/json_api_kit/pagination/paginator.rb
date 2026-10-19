# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Paginator
      def self.for(scope, order:, size:, after: nil, before: nil)
        raise ArgumentError, "a page is read from one end or the other" if after && before
        return Backwards.new(scope, order:, size:, from: order.position(before)) if before
        Forwards.new(scope, order:, size:, from: after && order.position(after))
      end

      def initialize(scope, order:, size:, from: nil)
        @scope = scope
        @order = order
        @size = size
        @from = from
      end

      def rows = window.rows

      private

      attr_reader :scope, :order, :size, :from

      def page_order = order

      def window = @window ||= Window.new(scope, order: page_order, size:, after: position)

      def position = @position ||= from&.in(page_order)

      def page_ahead
        return unless window.truncated?
        exit_position.to_cursor
      end

      def page_behind
        return unless from
        return unless probe.truncated?
        entry_position.to_cursor
      end

      def probe
        Window.new(scope, order: backwards, size: 0, after: entry_position.in(backwards))
      end

      def backwards = @backwards ||= page_order.reverse

      def exit_position = window.rows.last&.position || position

      def entry_position = window.rows.first&.position || position
    end
  end
end
