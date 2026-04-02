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

  def expect_schema_valid(schemer, params)
    valid = schemer.valid?(params)

    unless valid
      validation_result = schemer.validate(params).to_a[0]
      pointer = validation_result["data_pointer"]

      if pointer.present?
        at_pointer = value_at_json_pointer(params, pointer)
        puts "VALUE AT #{pointer.inspect}: #{at_pointer.inspect}"
        parent_pointer = pointer.sub(%r{/[^/]+\z}, "")
        if parent_pointer != pointer && parent_pointer.present?
          parent = value_at_json_pointer(params, parent_pointer)
          puts "PARENT AT #{parent_pointer.inspect}: #{parent.inspect}"
        end
      else
        puts "RESPONSE: #{params}"
      end

      details = validation_result["details"]
      if details
        puts "VALIDATION DETAILS: #{details}"
      else
        puts "POSSIBLE ISSUE W/: #{pointer}" if pointer.present?
      end
    end

    expect(valid).to eq(true)
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
