# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Declarations
        class Anchor
          class Attribute < Anchor
            def accepts?(anchoring) = anchoring.single_value?

            def locatable_in?(order) = order.leading.named?(name)

            def locate(anchoring, scope:, order:, guardian:)
              unless locatable_in?(order)
                raise ArgumentError,
                      "Anchor #{name} does not match the leading sort key #{order.leading.name}."
              end
              order.enter(scope, at_or_after: order.leading.at_or_after(scope, anchoring.value))
            end
          end
        end
      end
    end
  end
end
