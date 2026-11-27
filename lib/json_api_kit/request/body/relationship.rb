# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Relationship
        def initialize(location:, resource:)
          @location = location
          @resource = resource
        end

        def refusals
          return [forbidden_refusal] unless writable_by_guardian?

          contract.refusals
        rescue Glossary::NotAMemberName => error
          [ConversionError.new(error, location:)]
        end

        def parameter_name = declaration.parameter_name.to_sym

        def value = contract.value

        def locations_for(parameter)
          return [] unless parameter.for_relationship?(declaration)
          [parameter.linkage_location(location)]
        end

        private

        attr_reader :location, :resource

        delegate :glossary, to: :edition
        delegate :edition, to: :resource

        def declaration
          @declaration ||=
            resource.relationships.fetch(
              glossary.declared_relationship(member: location.name, type: resource.type),
              nil,
            )
        end

        def contract = @contract ||= declaration.contract_for(location:, glossary:)

        def writable_by_guardian?
          declaration&.readable_by?(resource.guardian) && declaration.writable?
        end

        def forbidden_refusal
          ConversionError.new(
            Forbidden.new("#{location.name} is not a writable relationship."),
            location:,
          )
        end
      end
    end
  end
end
