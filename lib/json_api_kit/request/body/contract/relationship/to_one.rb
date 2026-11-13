# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class Relationship
          class ToOne < Relationship
            validates_with JsonTypeValidator,
                           attributes: [:data],
                           with: :object_or_null,
                           if: :data_supplied?

            def value = identifiers.first&.id

            private

            def identifiers =
              @identifiers ||= Array.wrap(data.value).map { Identifier.new(location: data, type:) }
          end
        end
      end
    end
  end
end
