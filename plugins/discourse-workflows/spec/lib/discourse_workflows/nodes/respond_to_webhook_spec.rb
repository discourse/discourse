# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::RespondToWebhook::V1 do
  describe "#execute" do
    let(:item) { { "json" => { "user_id" => 42 } } }

    it "returns redirect response data" do
      config = { "response_type" => "redirect", "redirect_url" => "https://example.com/thanks" }
      result = execute_node(configuration: config, item: item)

      expect(result["response_type"]).to eq("redirect")
      expect(result["redirect_url"]).to eq("https://example.com/thanks")
      expect(result["allowed_redirect_domains"]).to eq([])
      expect(result["status_code"]).to eq(302)
    end

    it "returns normalized allowed redirect domains" do
      config = {
        "response_type" => "redirect",
        "redirect_url" => "https://example.com/thanks",
        "allowed_redirect_domains" => [
          { "domain" => " Example.com " },
          { "domain" => "*.Example.org" },
          { "domain" => "" },
        ],
      }
      result = execute_node(configuration: config, item: item)

      expect(result["allowed_redirect_domains"]).to eq(%w[example.com *.example.org])
    end

    it "returns JSON response data" do
      config = {
        "response_type" => "json",
        "status_code" => "201",
        "response_body" => '{"created": true}',
      }
      result = execute_node(configuration: config, item: item)

      expect(result["response_type"]).to eq("json")
      expect(result["status_code"]).to eq(201)
      expect(result["response_body"]).to eq('{"created": true}')
    end

    it "returns text response data" do
      config = { "response_type" => "text", "status_code" => "200", "response_body" => "OK thanks" }
      result = execute_node(configuration: config, item: item)

      expect(result["response_type"]).to eq("text")
      expect(result["status_code"]).to eq(200)
      expect(result["response_body"]).to eq("OK thanks")
    end

    it "returns no data response" do
      config = { "response_type" => "no_data", "status_code" => "204" }
      result = execute_node(configuration: config, item: item)

      expect(result["response_type"]).to eq("no_data")
      expect(result["status_code"]).to eq(204)
    end

    it "defaults status code to 200 for json" do
      config = { "response_type" => "json", "response_body" => "{}" }
      result = execute_node(configuration: config, item: item)

      expect(result["status_code"]).to eq(200)
    end

    it "includes custom headers when provided" do
      config = {
        "response_type" => "json",
        "response_body" => "{}",
        "headers" => [{ "key" => "X-Custom", "value" => "hello" }],
      }
      result = execute_node(configuration: config, item: item)

      expect(result["headers"]).to eq({ "X-Custom" => "hello" })
    end
  end
end
