# frozen_string_literal: true

module JsonApiKit
  module Page
    class Limits
      OutOfRange = Class.new(StandardError)

      DEFAULT = 25
      MAX = 100

      attr_reader :max

      def initialize(max: MAX, default: [DEFAULT, max].min)
        @max = max
        @default = default
        verify_bounds
      end

      def size(page_size = nil) = page_size || default

      private

      attr_reader :default

      def verify_bounds
        raise OutOfRange, "A maximum page size must be 1 or more, not #{max}." if max < 1
        return if default.between?(1, max)
        raise OutOfRange, "A default page size must be between 1 and #{max}, not #{default}."
      end
    end
  end
end
