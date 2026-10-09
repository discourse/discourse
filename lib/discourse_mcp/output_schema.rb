# frozen_string_literal: true

module DiscourseMcp
  module OutputSchema
    ANY = {}.freeze
    STRING = { type: "string" }.freeze
    INTEGER = { type: "integer" }.freeze
    BOOLEAN = { type: "boolean" }.freeze
    STRING_OR_NULL = { type: %w[string null] }.freeze
    INTEGER_OR_NULL = { type: %w[integer null] }.freeze
    BOOLEAN_OR_NULL = { type: %w[boolean null] }.freeze
    ARRAY = { type: "array" }.freeze
    STRING_ARRAY = { type: "array", items: STRING }.freeze
    OBJECT_ARRAY = { type: "array", items: { type: "object" } }.freeze
    OBJECT = { type: "object" }.freeze

    module_function

    def object(optional: [], **properties)
      {
        type: "object",
        properties:,
        required: properties.keys.map(&:to_s) - optional,
        additionalProperties: false,
      }
    end
  end
end
