# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class Relationship
          class ToMany < Relationship
            validates_with JsonTypeValidator, attributes: [:data], with: :array, if: :data_supplied?

            def value = identifiers.map(&:id)

            private

            def identifiers
              @identifiers ||=
                data.value.each_index.map { Identifier.new(location: data.child(it), type:) }
            end
          end
        end
      end
    end
  end
end
