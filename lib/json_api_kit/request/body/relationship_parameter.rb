# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class RelationshipParameter
        def initialize(parameter, entries:, location:, resource:)
          @parameter = ParameterPath.for(parameter)
          @entries = entries
          @location = location
          @resource = resource
        end

        def locations
          submitted_locations.then { |origins| origins.empty? ? omitted_locations : origins }
        end

        private

        attr_reader :parameter, :entries, :location, :resource

        delegate :edition, to: :resource
        delegate :glossary, to: :edition

        def submitted_locations = entries.flat_map { it.locations_for(parameter) }

        def omitted_locations
          Array
            .wrap(declaration)
            .map do |relationship|
              location.child(
                glossary.member_relationship(declared: relationship.name, type: resource.type),
                "data",
              )
            end
        end

        def declaration
          resource
            .relationships
            .fetch(parameter.name.to_s) { resource.relationships.for_parameter(parameter.name) }
        end
      end
    end
  end
end
