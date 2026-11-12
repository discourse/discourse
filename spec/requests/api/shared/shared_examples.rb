# frozen_string_literal: true

RSpec.shared_examples "a JSON endpoint" do |expected_response_status|
  before { |example| submit_request(example.metadata) }

  # JSON Pointer (RFC 6901) path, e.g. "/upcoming_changes_stats/0/name" resolves to that value.
  def value_at_json_pointer(data, pointer)
    return data if pointer.blank?

    pointer
      .to_s
      .split("/")
      .reject(&:empty?)
      .reduce(data) do |node, segment|
        key = segment.match?(/\A\d+\z/) ? segment.to_i : segment
        node&.dig(key)
      end
  end

  def format_json_value(value)
    formatted = JSON.pretty_generate(value)
    formatted.length > 1200 ? "#{formatted[0...1200]}\n... <truncated>" : formatted
  rescue JSON::GeneratorError, TypeError
    value.inspect
  end

  def schema_for_json_value(value)
    case value
    when Hash
      if value.empty?
        { type: "object", additionalProperties: true }
      else
        {
          type: "object",
          additionalProperties: false,
          properties: value.transform_values { |nested_value| schema_for_json_value(nested_value) },
          required: value.keys,
        }
      end
    when Array
      item = value.compact.first
      schema = { type: "array" }
      schema[:items] = schema_for_json_value(item) if item
      schema
    when String
      { type: "string" }
    when Integer
      { type: "integer" }
    when Numeric
      { type: "number" }
    when TrueClass, FalseClass
      { type: "boolean" }
    when NilClass
      { type: "null" }
    else
      {}
    end
  end

  def json_pointer_leaf(pointer)
    pointer.to_s.split("/").reject(&:empty?).last
  end

  def schema_validation_issue(validation_result)
    pointer = validation_result["data_pointer"].presence || "root"

    case validation_result["type"]
    when "required"
      missing_keys = validation_result.dig("details", "missing_keys") || []
      "Missing required #{"property".pluralize(missing_keys.size)} #{missing_keys.join(", ")} at #{pointer}"
    when "schema"
      "Unexpected property at #{pointer}"
    else
      validation_result["error"] || "Schema mismatch at #{pointer}"
    end
  end

  def schema_validation_suggested_fix(validation_result, params)
    schema_pointer = validation_result["schema_pointer"].presence || "root schema"
    data_pointer = validation_result["data_pointer"].presence
    value = value_at_json_pointer(params, data_pointer)

    case validation_result["type"]
    when "required"
      missing_keys = validation_result.dig("details", "missing_keys") || []
      "Add #{missing_keys.join(", ")} to the response/request, or remove it from `required` at #{schema_pointer}."
    when "schema"
      property_name = json_pointer_leaf(data_pointer)
      snippet = { property_name => schema_for_json_value(value) }
      "If this response/request field is intentional, add this entry to the parent schema's `properties` object:\n#{format_json_value(snippet).indent(6)}\n      If the field is always present, also add #{property_name.inspect} to the parent schema's `required` array."
    when "array", "object", "string", "integer", "number", "boolean", "null"
      "Update the payload to match the documented `type`, or replace the schema at #{schema_pointer} with:\n#{format_json_value(schema_for_json_value(value)).indent(6)}"
    when "enum"
      "Return one of the documented enum values, or add this value to the enum at #{schema_pointer}."
    else
      "Compare the value at the data path with the schema at #{schema_pointer}."
    end
  end

  def format_schema_validation_result(validation_result, params, index)
    pointer = validation_result["data_pointer"].presence
    parent_pointer = pointer&.sub(%r{/[^/]+\z}, "")
    lines = [
      "#{index}. #{schema_validation_issue(validation_result)}",
      "   Error: #{validation_result["error"]}",
      "   Data path: #{pointer || "root"}",
      "   Schema path: #{validation_result["schema_pointer"].presence || "root"}",
      "   Value:",
      format_json_value(value_at_json_pointer(params, pointer)).indent(5),
    ]

    if parent_pointer.present? && parent_pointer != pointer
      lines.concat(
        [
          "   Parent path: #{parent_pointer}",
          "   Parent value:",
          format_json_value(value_at_json_pointer(params, parent_pointer)).indent(5),
        ],
      )
    end

    if validation_result["details"].present?
      lines.concat(["   Details:", format_json_value(validation_result["details"]).indent(5)])
    end

    lines.concat(
      ["   Suggested fix: #{schema_validation_suggested_fix(validation_result, params)}"],
    )
    lines.join("\n")
  end

  def schema_validation_failure_message(validation_results, params)
    formatted_results =
      validation_results
        .map
        .with_index(1) do |validation_result, index|
          format_schema_validation_result(validation_result, params, index)
        end

    <<~MESSAGE
      JSON schema validation failed with #{validation_results.size} #{"error".pluralize(validation_results.size)}:

      #{formatted_results.join("\n\n")}
    MESSAGE
  end

  def expect_schema_valid(schemer, params)
    validation_results = schemer.validate(params).to_a
    if validation_results.any?
      raise RSpec::Expectations::ExpectationNotMetError,
            schema_validation_failure_message(validation_results, params)
    end
  end

  describe "response status" do
    it "returns expected response status" do
      expect(response.status).to eq(expected_response_status)
    end
  end

  describe "request body" do
    it "matches the documented request schema" do |example|
      if expected_request_schema
        schemer = JSONSchemer.schema(expected_request_schema)
        expect_schema_valid(schemer, params)
      end
    end
  end

  describe "response body" do
    let(:json_response) { JSON.parse(response.body) }

    it "matches the documented response schema" do |example|
      if expected_response_schema
        schemer = JSONSchemer.schema(expected_response_schema)
        expect_schema_valid(schemer, json_response)
      end
    end
  end
end
