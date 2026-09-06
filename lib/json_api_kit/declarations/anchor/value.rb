# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Anchor
      class Value
        def initialize(key, value)
          @key = key
          @value = value
        end

        def locate(scope, order:)
          order.enter(scope, at_or_after: key.at_or_after(scope, value))
        end

        private

        attr_reader :key, :value
      end
    end
  end
end
