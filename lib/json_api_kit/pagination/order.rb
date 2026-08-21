# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      attr_reader :segments

      delegate :leading, to: :keyset
      delegate :first, :columns, :locate, to: :segments
      delegate :fetch, :after, to: :segments

      def initialize(keyset)
        @keyset = keyset
        @segments = Segments.for(keyset)
      end

      def reverse = self.class.new(keyset.reverse)

      def position(cursor) = Position.from(cursor, order: self)

      def compatible_with?(cursor:)
        position(cursor)
        true
      rescue KeyError, ArgumentError
        false
      end

      def split? = segments.size > 1

      def enter(scope, at_or_after:)
        locate(at_or_after) || segments.after_every_value_of(leading.name).locate(scope)
      end

      private

      attr_reader :keyset
    end
  end
end
