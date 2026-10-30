# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class Identifier < Member
          validates_with JsonTypeValidator, attributes: [:base], with: :object
          validates_with JsonTypeValidator, attributes: %i[type id], with: :string, if: :object?
          validates :type, comparison: { equal_to: :expected_type }, if: :string_type?

          def initialize(location:, type:)
            super(location:)
            @expected_type = type
          end

          attr_reader :expected_type

          def id = location_for(:id).value

          private

          def string_type? = location_for(:type).string?
        end
      end
    end
  end
end
