# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Cursor
      UnsupportedValue = Class.new(ArgumentError)

      class << self
        def valid?(raw)
          parse(raw)
          true
        rescue ArgumentError
          false
        end

        def parse(raw)
          values = JSON.parse(Base64.urlsafe_decode64(raw.to_s))
          raise ArgumentError, "a cursor holds a list of values" unless values.is_a?(Array)
          new(values)
        rescue JSON::ParserError
          raise ArgumentError, "a cursor is JSON in base64"
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
