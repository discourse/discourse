# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # An opaque paging position: one row's keyset values, in keyset order.
    #
    # Values are held in their wire form whichever end they came from, so a cursor
    # minted from a record and one parsed off a request compare identically.
    #
    # The encoding has to be lossless, and two conversions are not: `Time#to_json`
    # truncates to milliseconds where Postgres keeps microseconds, and a zoned
    # timestamp cast to `timestamp without time zone` keeps its local wall clock. A
    # cursor whose timestamp lands anywhere but on its own row's value repeats that
    # row or skips its neighbour.
    class Cursor
      Invalid = Class.new(StandardError)
      UnsupportedValue = Class.new(ArgumentError)

      class << self
        def parse(raw)
          new(decode(raw))
        rescue UnsupportedValue => e
          raise Invalid, e.message
        end

        private

        def decode(raw)
          JSON
            .parse(Base64.urlsafe_decode64(raw.to_s))
            .tap { raise Invalid, "a cursor holds a list of values" unless it.is_a?(Array) }
        rescue ArgumentError, JSON::ParserError
          raise Invalid, "a cursor is a base64-encoded list of values"
        end
      end

      attr_reader :values

      def initialize(values)
        @values = values.map { encode(it) }
      end

      def size = values.size

      def to_s = @encoded ||= Base64.urlsafe_encode64(JSON.generate(values), padding: false)

      def ==(other) = other.is_a?(self.class) && other.values == values

      private

      def encode(value)
        return value.getutc.iso8601(6) if value.acts_like?(:time)
        return value.iso8601 if value.acts_like?(:date)

        case value
        when BigDecimal
          value.to_s
        when nil, true, false, String, Numeric
          value
        else
          raise UnsupportedValue, "a #{value.class} cannot travel in a cursor"
        end
      end
    end
  end
end
