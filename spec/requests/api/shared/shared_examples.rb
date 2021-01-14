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
      errors = expected_request_schema.schema.fully_validate(params)
      puts params if errors.count > 0 # for debugging
      expect(errors).to be_empty
    end
  end

  describe "response body" do
    let(:json_response) { JSON.parse(response.body) }

    it "matches the documented response schema" do  |example|
      errors = expected_response_schema.schema.fully_validate(json_response)
      puts json_response if errors.count > 0 # for debugging
      expect(errors).to be_empty
    end
  end
end
