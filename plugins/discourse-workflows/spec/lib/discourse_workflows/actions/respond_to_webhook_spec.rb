# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::RespondToWebhook::V1 do
  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:respond_to_webhook")
    end
  end

  describe "#execute_single" do
    let(:action) { described_class.new(configuration: {}) }
    let(:context) { { "trigger" => {} } }
    let(:item) { { "json" => { "user_id" => 42 } } }

    it "returns redirect response data" do
      config = { "response_type" => "redirect", "redirect_url" => "https://example.com/thanks" }
      result = action.execute_single(context, item: item, config: config)

      expect(result[:response_type]).to eq("redirect")
      expect(result[:redirect_url]).to eq("https://example.com/thanks")
      expect(result[:status_code]).to eq(302)
    end

    it "returns JSON response data" do
      config = {
        "response_type" => "json",
        "status_code" => "201",
        "response_body" => '{"created": true}',
      }
      result = action.execute_single(context, item: item, config: config)

      expect(result[:response_type]).to eq("json")
      expect(result[:status_code]).to eq(201)
      expect(result[:response_body]).to eq('{"created": true}')
    end

    it "returns text response data" do
      config = {
        "response_type" => "text",
        "status_code" => "200",
        "response_body" => "OK thanks",
      }
      result = action.execute_single(context, item: item, config: config)

      expect(result[:response_type]).to eq("text")
      expect(result[:status_code]).to eq(200)
      expect(result[:response_body]).to eq("OK thanks")
    end

    it "returns no data response" do
      config = { "response_type" => "no_data", "status_code" => "204" }
      result = action.execute_single(context, item: item, config: config)

      expect(result[:response_type]).to eq("no_data")
      expect(result[:status_code]).to eq(204)
    end

    it "defaults status code to 200 for json" do
      config = { "response_type" => "json", "response_body" => "{}" }
      result = action.execute_single(context, item: item, config: config)

      expect(result[:status_code]).to eq(200)
    end

    it "includes custom headers when provided" do
      config = {
        "response_type" => "json",
        "response_body" => "{}",
        "headers" => [
          { "key" => "X-Custom", "value" => "hello" },
        ],
      }
      result = action.execute_single(context, item: item, config: config)

      expect(result[:headers]).to eq({ "X-Custom" => "hello" })
    end
  end
end
