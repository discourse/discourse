# frozen_string_literal: true

RSpec::Matchers.define :match_node_output_schema do |node_class, configuration: {}, input_schemas: [], output_index: 0|
  match do |output|
    @resolved_schema = nil
    @validation_errors = []
    @non_hash_output = !output.is_a?(Hash)

    if @non_hash_output
      false
    else
      @resolved_schema =
        node_class.output_schemas(configuration, input_schemas: input_schemas)[output_index] || {}

      if @resolved_schema.blank?
        false
      else
        @validation_errors =
          JSONSchemer.schema(@resolved_schema).validate(output.deep_stringify_keys).to_a
        @validation_errors.empty?
      end
    end
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
