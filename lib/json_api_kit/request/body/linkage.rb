# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Linkage
        def self.parse(json, **options) = new(Body.parse_json(json), **options)

        def initialize(document, relationship:, resource:)
          @document = document
          @relationship = relationship
          @resource = resource
        end

        def invalid? = refusals.any?

        def parameters
          raise Invalid.new(refusals) if invalid?
          @parameters ||= { parameter_name => contract.value }
        end

        def refusals = @refusals ||= errors_refusals + contract.refusals

        def validation_errors(errors)
          errors.map do |error|
            ValidationError.new(error, location: location_for(ParameterPath.for(error.attribute)))
          end
        end

        private

        attr_reader :document, :relationship, :resource

        delegate :edition, to: :resource, private: true
        delegate :glossary, to: :edition, private: true

        def root = @root ||= Location.new(document, [])

        def parameter_name = relationship.parameter_name.to_sym

        def contract = @contract ||= relationship.contract_for(location: root, glossary:)

        def errors_refusals
          return [] unless root.object?
          return [] unless root.child("data").supplied?
          return [] unless root.child("errors").supplied?

          [
            Error.new(
              ActiveModel::Error.new(contract, :errors, :incompatible),
              location: root.child("errors"),
            ),
          ]
        end

        def location_for(path)
          return root if path.base? || !path.for_relationship?(relationship)
          path.linkage_location(root)
        end
      end
    end
  end
end
