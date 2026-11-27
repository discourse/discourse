# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Unreadable < BadRequest
        def title = "Invalid request body"

        def detail = "The request body must contain valid JSON."
      end

      def self.parse(json, **options)
        new(JSON.parse(json), **options)
      rescue JSON::ParserError
        raise Unreadable
      end

      def initialize(document, resource:)
        @document = document
        @resource = resource
      end

      def invalid? = refusals.any?

      def parameters
        raise Invalid.new(refusals) if invalid?
        @parameters ||= attributes.parameters.merge(relationships.parameters)
      end

      def locations_for(parameter)
        ParameterPath
          .for(parameter)
          .then { |path| relationships.locations_for(path) + attributes.locations_for(path.name) }
      end

      def to_h = document

      def refusals
        @refusals ||=
          if contract.invalid?
            contract.errors.map { Error.new(it, document:) }
          else
            relationships.refusals + relationships.attribute_refusals(attributes)
          end
      rescue ConversionError => error
        [error]
      end

      def validation_errors(errors)
        errors.map do |error|
          ValidationError.new(error, location: location_for(ParameterPath.for(error.attribute)))
        end
      end

      private

      attr_reader :document, :resource

      delegate :edition, :type, to: :resource
      delegate :glossary, to: :edition

      def contract = @contract ||= Contract::Create.new(document, type: glossary.member_type(type))

      def attributes =
        @attributes ||= Attributes.new(document, glossary:, existing: existing_values)

      def relationships = @relationships ||= Relationships.new(document, resource:)

      def location_for(parameter)
        return attributes.location_for(parameter) if parameter.base?
        relationships.locations_for(parameter).sole
      rescue Enumerable::SoleItemExpectedError
        attributes.location_for(parameter)
      end

      def existing_values = ExistingValues::None
    end
  end
end
