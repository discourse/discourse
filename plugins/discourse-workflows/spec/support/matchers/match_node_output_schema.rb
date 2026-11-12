# frozen_string_literal: true

RSpec::Matchers.define :match_node_output_schema do |node_class, configuration: {}, input_schemas: [], output_index: 0|
  match do |output|
    next false if (@non_hash_output = !output.is_a?(Hash))

    @resolved_schema =
      node_class.output_schemas(configuration, input_schemas: input_schemas)[output_index] || {}
    next false if @resolved_schema.blank?

    @validation_errors =
      JSONSchemer
        .schema(require_declared_properties(@resolved_schema))
        .validate(output.deep_stringify_keys)
        .to_a
    @validation_errors.empty?
  end

  def require_declared_properties(schema)
    case schema
    when Hash
      strict = schema.transform_values { |value| require_declared_properties(value) }
      return strict if !schema["properties"].is_a?(Hash)

      strict["required"] = schema["properties"].reject { |_, value| optional?(value) }.keys
      strict["properties"] = strict["properties"].to_h do |name, value|
        next name, value if !optional?(value) || value["type"] != "object"
        [name, { "anyOf" => [{ "type" => "object", "maxProperties" => 0 }, value] }]
      end
      strict
    when Array
      schema.map { |value| require_declared_properties(value) }
    else
      schema
    end
  end

  def optional?(schema)
    schema.is_a?(Hash) && schema["x-optional"]
  end

  failure_message do |output|
    node_name = node_class.name.presence || node_class.to_s

    if @non_hash_output
      "expected node output to be a Hash, got #{output.class}"
    elsif @resolved_schema.blank?
      "expected #{node_name} to resolve a concrete output schema, but it resolved #{@resolved_schema.inspect}"
    else
      details =
        @validation_errors
          .map do |error|
            schema_pointer = error["schema_pointer"].presence || "/"
            "#{JSONSchemer::Errors.pretty(error)} [schema: #{schema_pointer}]"
          end
          .join("\n")

      "expected output to match #{node_name}'s output schema:\n#{details}"
    end
  end
end
