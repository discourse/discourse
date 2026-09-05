# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Anchor
      class Computed
        def initialize(condition, guardian)
          @condition = condition
          @guardian = guardian
        end

        def locate(scope, order:) = order.locate(condition.call(scope, guardian))

        private

        attr_reader :condition, :guardian
      end
    end
  end
end
