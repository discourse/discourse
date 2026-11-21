# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class Member
          include ActiveModel::Validations

          def initialize(location:)
            @location = location
          end

          def read_attribute_for_validation(attribute) = location_for(attribute).value

          def refusals
            valid?
            errors.map { |error| original_error(error).then { it.base.refusal_for(it) } }
          end

          def refusal_for(error) = Error.new(error, location: location_for(error.attribute))

          private

          attr_reader :location

          def location_for(attribute)
            attribute == :base ? location : location.child(attribute.to_s)
          end

          def object? = location.object?

          def original_error(error)
            return error unless error.is_a?(ActiveModel::NestedError)
            original_error(error.inner_error)
          end
        end
      end
    end
  end
end
