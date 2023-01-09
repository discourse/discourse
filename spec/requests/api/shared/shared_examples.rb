# frozen_string_literal: true

RSpec.shared_examples "a JSON endpoint" do |expected_response_status|
  before { |example| submit_request(example.metadata) }

  def expect_schema_valid(schemer, params)
    valid = schemer.valid?(params)
    unless valid # for debugging
      puts
      puts "RESPONSE: #{params}"
      validation_result = schemer.validate(params).to_a[0]
      details = validation_result["details"]
      if details
        puts "VALIDATION DETAILS: #{details}"
      else
        puts "POSSIBLE ISSUE W/: #{validation_result["data_pointer"]}"
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
