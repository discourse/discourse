# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # A page of a listing: the records to render, and the cursors of the pages either side
    # of it.
    #
    # A page is read from one end or the other, never both, so which end decides everything
    # that varies — the direction the order is walked, whether the rows come back in the
    # order they are presented in, and which side the window answers for rather than probes.
    # Each end is its own reading (see Forwards and Backwards).
    class Paginator
      def self.for(scope, order:, size:, after: nil, before: nil)
        raise ArgumentError, "a page is read from one end or the other" if after && before
        return Backwards.new(scope, order:, size:, cursor: before) if before
        Forwards.new(scope, order:, size:, cursor: after)
      end

      def initialize(scope, order:, size:, cursor: nil)
        @scope = scope
        @order = order
        @size = size
        @cursor = cursor
      end

      def rows = window.rows

      def records = rows.map(&:record)

      private

      attr_reader :scope, :order, :size, :cursor

      # The order as this page walks it: the declared one, or its reverse (see Backwards).
      def reading = order

      def window = @window ||= Window.new(scope, order: reading, size:, after: position)

      # The cursor a client sent, resolved against the order this page reads.
      def position = @position ||= cursor && reading.position(cursor)

      # The page continuing the way this one was read, if the order carries on past it.
      def further
        return if !window.truncated?
        exit_position.to_cursor
      end

      # The page on the side this one was entered from, if anything lies there. Nothing was read
      # that way, so it takes a probe to find out — unless this page was read from the very
      # start of the order, where nothing can lie behind it and no query is needed.
      def behind
        return if cursor.nil? || !probe.truncated?
        entry_position.to_cursor
      end

      def probe
        Window.new(scope, order: backwards, size: 0, after: entry_position.in(backwards))
      end

      # The order this page was read in, walked the other way — built once, so the segments a
      # position names are the ones the probe reads.
      def backwards = @backwards ||= reading.reverse

      # Where the page ended and where it began, in the order it was read. A page that read
      # nothing falls back to the position it was read from, so a client that lands on an empty
      # page can still step away from it.
      def exit_position = window.rows.last&.position || position

      def entry_position = window.rows.first&.position || position
    end
  end
end
