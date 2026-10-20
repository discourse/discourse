# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Anchor
      class Identity < Anchor
        def accepts?(anchoring) = anchoring.single_value?

        def locatable_in?(_order) = true

        def locate(anchoring, scope:, order:, guardian:)
          order.locate(scope.where(scope.primary_key => anchoring.value)) or
            raise NoRow.new(name, anchoring.value)
        end
      end
    end
  end
end
