# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Anchor
      class Computed < Anchor
        def initialize(name, &condition)
          super(name)
          @condition = condition
        end

        def accepts?(anchoring) = anchoring.without_value?

        def locatable_in?(_order) = true

        def locate(_anchoring, scope:, order:, guardian:) =
          order.locate(condition.call(scope, guardian))

        private

        attr_reader :condition
      end
    end
  end
end
