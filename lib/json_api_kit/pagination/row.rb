# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Row
      attr_reader :record

      def initialize(record:, segment:)
        @record = record
        @segment = segment
      end

      def position = @position ||= segment.position_of(record)

      def cursor = position.to_cursor

      private

      attr_reader :segment
    end
  end
end
