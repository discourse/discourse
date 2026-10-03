# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Error < JsonApiKit::Error
        Rule =
          Data.define(:status, :description) do
            def detail(error, location) = description.call(error, location)
          end

        JSON_TYPES = { object: "an object", string: "a string" }.freeze
        DEFAULT_RULE = Rule.new("400", ->(error, _) { error.message })
        RULES = {
          :json_type =>
            Rule.new(
              "400",
              ->(error, location) do
                "#{location.name} must be #{JSON_TYPES.fetch(error.options[:expected])}."
              end,
            ),
          [:"data.type", :equal_to] =>
            Rule.new(
              "409",
              ->(error, _) { "type must be #{error.options[:count]} for this endpoint." },
            ),
          [:"data.id", :unsupported] =>
            Rule.new("403", ->(*) { "This endpoint does not accept client-generated IDs." }),
          %i[errors incompatible] =>
            Rule.new("400", ->(*) { "data and errors must not appear in the same document." }),
        }.freeze

        def initialize(error, document:)
          @error = error
          @location = Location.for(error.attribute, document:)
          @rule =
            RULES.fetch([error.attribute, error.type]) { RULES.fetch(error.type, DEFAULT_RULE) }
          super()
        end

        delegate :status, to: :rule

        def title = "Invalid request body"

        def detail = rule.detail(error, location)

        def source = { pointer: location.nearest_existing.pointer }

        private

        attr_reader :error, :location, :rule
      end
    end
  end
end
