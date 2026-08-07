# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # A row of a listing at its place in it: the record to render, and the position that
    # place is named by.
    #
    # Rows are what a page is made of, because every one of them can be paged from — the
    # cursor-pagination profile gives each item in a listing a cursor of its own.
    class Row
      attr_reader :record

      def initialize(record:, segment:)
        @record = record
        @segment = segment
      end

      # Worked out when it is asked for: a page of fifty rows is usually read for its records,
      # and only its own two ends are ever named.
      def position = @position ||= segment.position_of(record)

      def cursor = position.to_cursor

      private

      attr_reader :segment
    end
  end
end
