# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class Relationship < Member
          validates_with JsonTypeValidator, attributes: [:base], with: :object
          validate :require_data, if: :object?

          def initialize(location:, type:)
            super(location:)
            @type = type
          end

          def valid?(context = nil)
            return false unless super
            identifiers.each do |identifier|
              identifier.valid?(context)
              errors.merge!(identifier.errors)
            end
            errors.empty?
          end

          private

          attr_reader :type

          def data = location_for(:data)

          def data_supplied? = data.supplied?

          def require_data
            errors.add(:data, :missing) unless data_supplied?
          end
        end
      end
    end
  end
end
