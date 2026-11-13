# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class Update < Contract
          validates :"data.id", json_type: :string, if: :resource_object?
          validates :"data.id", comparison: { equal_to: :expected_id }, if: :string_id?

          def initialize(document, type:, id:)
            super(document, type:)
            @expected_id = id
          end

          attr_reader :expected_id

          private

          def string_id? = location(:"data.id").string?
        end
      end
    end
  end
end
