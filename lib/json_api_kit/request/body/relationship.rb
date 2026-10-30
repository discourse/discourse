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
          unless declaration&.writable?
            return [
              ConversionError.new(
                Forbidden.new("#{location.name} is not a writable relationship."),
                location:,
              ),
            ]
          end
          contract.refusals
        rescue Glossary::NotAMemberName => error
          [ConversionError.new(error, location:)]
        end

        def parameter_name = declaration.parameter_name.to_sym

        def value = contract.value

        def locations_for(parameter)
          unless parameter.name == parameter_name || parameter.name.to_s == declaration.name
            return []
          end
          [location_for(parameter)]
        end

        private

        attr_reader :location, :resource

        delegate :glossary, to: :edition
        delegate :edition, to: :resource

        def location_for(parameter)
          parameter.index ? location.child("data", parameter.index, "id") : location.child("data")
        end

        def declaration
          @declaration ||=
            resource.relationships.fetch(
              glossary.declared_relationship(member: location.name, type: resource.type),
              nil,
            )
        end

        def contract
          @contract ||=
            declaration.input_contract.new(
              location:,
              type: glossary.member_type(declaration.resource.type),
            )
        end
      end
    end
  end
end
