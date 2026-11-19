# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Relationships
        def initialize(document, resource:)
          @location = Location.new(document, %w[data relationships])
          @resource = resource
        end

        def refusals = entries.flat_map(&:refusals)

        def parameters = entries.to_h { [it.parameter_name, it.value] }

        def locations_for(parameter)
          RelationshipParameter.new(parameter, entries:, location:, resource:).locations
        end

        def attribute_refusals(attributes)
          resource.relationships.parameter_names.flat_map do |parameter|
            attributes
              .locations_for(parameter)
              .map do |origin|
                ConversionError.new(
                  BadRequest.new("#{parameter} must be supplied through relationships."),
                  location: origin,
                )
              end
          end
        end

        private

        attr_reader :location, :resource

        def entries
          @entries ||=
            (location.value || {}).keys.map do |name|
              Relationship.new(location: location.child(name), resource:)
            end
        end
      end
    end
  end
end
