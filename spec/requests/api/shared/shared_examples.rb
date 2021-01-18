# frozen_string_literal: true

RSpec.shared_examples "a JSON endpoint" do |expected_response_status|
  before do |example|
    submit_request(example.metadata)
  end

  describe "response status" do
    it "returns expected response status" do
      expect(response.status).to eq(expected_response_status)
    end
  end

  describe "request body" do
    it "matches the documented request schema" do |example|
      schemer = JSONSchemer.schema(expected_request_schema.schemer)
      valid = schemer.valid?(params)
      unless valid # for debugging
        puts params
        puts schemer.validate(params).to_a[0]["details"]
      end
      expect(valid).to eq(true)
    end
  end

  describe "response body" do
    let(:json_response) { JSON.parse(response.body) }

    it "matches the documented response schema" do  |example|
      schemer = JSONSchemer.schema(
        expected_response_schema.schemer,
      )
      valid = schemer.valid?(json_response)
      unless valid # for debugging
        puts json_response
        puts schemer.validate(json_response).to_a[0]["details"]
      end
      expect(valid).to eq(true)
    end
  end
end
