# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Attributes
        def initialize(document, glossary:, existing: ExistingValues::None)
          @document = document
          @glossary = glossary
          @existing = existing
        end

        def parameters
          @parameters ||=
            glossary
              .declared_attributes(submitted_attributes.deep_dup, existing:)
              .transform_keys { it.value.to_sym }
        rescue Glossary::NotAMemberName => error
          raise ConversionError.new(error, location: error_location([error.raw]))
        rescue Glossary::BadValue => error
          raise ConversionError.new(error, location: error_location(error.names))
        rescue VersionChange::Converter::Tuple::InvalidResult => error
          raise unless error.up?
          raise ConversionError.new(
                  Glossary::BadValue.new(error.names),
                  location: error_location(error.names),
                )
        end

        def locations_for(parameter)
          origins.fetch(parameter.to_sym, [])
        rescue Glossary::NotAMemberName => error
          raise ConversionError.new(error, location: error_location([error.raw]))
        end

        def location_for(parameter)
          return Location.new(document, %w[data]) if parameter == :base
          locations_for(parameter.to_s.split(/[.\[]/, 2).first).sole
        rescue Enumerable::SoleItemExpectedError
          Location.new(document, %w[data attributes])
        end

        private

        attr_reader :document, :glossary, :existing

        def resource_object = document.fetch("data")

        def submitted_attributes
          @submitted_attributes ||=
            resource_object
              .fetch("attributes", {})
              .to_h do |name, value|
                [Name::Field.new(value: name, type: resource_object.fetch("type")), value]
              end
        end

        def origins
          @origins ||=
            submitted_attributes
              .each_key
              .each_with_object({}) do |name, locations|
                glossary
                  .declared_names(name)
                  .each do |declared_name|
                    (locations[declared_name.value.to_sym] ||= []) << location(name)
                  end
              end
              .transform_values(&:freeze)
        end

        def location(name) = Location.new(document, ["data", "attributes", name.value])

        def error_location(names)
          names.uniq.filter_map { location(it) if submitted_attributes.key?(it) }.sole
        rescue Enumerable::SoleItemExpectedError
          Location.new(document, %w[data attributes])
        end
      end
    end
  end
end
