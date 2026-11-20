# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        include ActiveModel::Validations

        validates :base, json_type: :object
        validates :data, json_type: :object, if: :document_object?
        validates :"data.type", json_type: :string, if: :resource_object?
        validates :"data.type", comparison: { equal_to: :expected_type }, if: :string_type?
        validates :"data.attributes", json_type: :object, if: :attributes_supplied?

        validate :check_id, if: :resource_object?
        validate :check_errors, if: :document_object?

        def initialize(document, type:)
          @locations =
            Hash.new do |locations, attribute|
              locations[attribute] = Location.for(attribute, document:)
            end
          @expected_type = type
        end

        attr_reader :expected_type

        def read_attribute_for_validation(attribute) = location(attribute).value

        private

        attr_reader :locations

        def location(attribute) = locations[attribute]

        def document_object? = location(:base).object?

        def resource_object? = location(:data).object?

        def string_type? = location(:"data.type").string?

        def attributes_supplied? = location(:"data.attributes").supplied?

        def check_id
          errors.add(:"data.id", :unsupported) if location(:"data.id").supplied?
        end

        def check_errors
          if location(:data).supplied? && location(:errors).supplied?
            errors.add(:errors, :incompatible)
          end
        end
      end
    end
  end
end
