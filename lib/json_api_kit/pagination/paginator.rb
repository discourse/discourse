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
      def self.for(scope, keyset:, size:, after: nil, before: nil)
        raise ArgumentError, "a page is read from one end or the other" if after && before
        return Backwards.new(scope, keyset:, size:, cursor: before) if before
        Forwards.new(scope, keyset:, size:, cursor: after)
      end

      def initialize(scope, keyset:, size:, cursor: nil)
        @scope = scope
        @keyset = keyset
        @size = size
        @cursor = cursor
      end

      def records = window.records

      private

      attr_reader :scope, :keyset, :size, :cursor

      # The order as this page walks it: the declared one, or its reverse (see Backwards).
      def reading = keyset

      def window = @window ||= Window.new(scope, keyset: reading, size:, after: cursor)

      # The page continuing the way this one was read, if the order carries on past it.
      def further
        return if !window.truncated?
        exit_cursor
      end

      # The page on the side this one was entered from, if anything lies there. Nothing was
      # read that way, so it takes a probe to find out.
      def behind
        return if entry_cursor.nil? || !probe.truncated?
        entry_cursor
      end

      def probe = Window.new(scope, keyset: reading.reverse, size: 0, after: entry_cursor)

      # Where the page ended and where it began, in the order it was read. A page that read
      # nothing falls back to the cursor it was read from, so a client that lands on an empty
      # page can still step away from it.
      def exit_cursor = window.last_cursor || cursor

      def entry_cursor = window.first_cursor || cursor
    end
  end
end
