# frozen_string_literal: true

module JsonApiKit
  class Request
    class ParameterName
      def initialize(*parts)
        @parts = parts.map(&:to_s)
      end

      def family = self.class.new(parts.first)

      def member(part) = self.class.new(*parts, part)

      def to_s = "#{parts.first}#{parts.drop(1).map { "[#{it}]" }.join}"

      private

      attr_reader :parts
    end
  end
end
