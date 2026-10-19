# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Cursor
      UnsupportedValue = Class.new(ArgumentError)

      TIME = ->(value) { value.acts_like?(:time) }
      DATE = ->(value) { value.acts_like?(:date) }
      private_constant :TIME, :DATE

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
          new(values.map { coerce(it) })
        rescue JSON::ParserError
          raise ArgumentError, "a cursor is JSON in base64"
        end

        def coerce(value)
          case value
          when TIME
            value.getutc.iso8601(6)
          when DATE
            value.iso8601
          when BigDecimal
            value.to_s
          when nil, true, false, String, Numeric
            value
          else
            raise UnsupportedValue, "a #{value.class} cannot travel in a cursor"
          end
        end
      end

      attr_reader :values

      def initialize(values) = @values = values

      def to_s = @to_s ||= Base64.urlsafe_encode64(JSON.generate(values), padding: false)

      def ==(other) = other.is_a?(self.class) && other.values == values
    end
  end
end
