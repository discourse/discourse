# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::HttpRequest::V1 do
  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:http_request")
    end
  end

  describe "#execute_single" do
    let(:action) { described_class.new(configuration: {}) }
    let(:context) { { "trigger" => {} } }
    let(:item) { { "json" => {} } }

    it "makes a GET request and returns parsed JSON response" do
      stub_request(:get, "https://api.example.com/data").to_return(
        status: 200,
        body: { result: "ok" }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = { "method" => "GET", "url" => "https://api.example.com/data" }
      result = action.execute_single(context, item: item, config: config)

      expect(result[:status]).to eq(200)
      expect(result[:body]).to eq("result" => "ok")
    end

    it "appends query parameters to the URL" do
      stub_request(:get, "https://api.example.com/data?page=1&per=10").to_return(
        status: 200,
        body: "[]",
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "GET",
        "url" => "https://api.example.com/data",
        "query_params" => [
          { "key" => "page", "value" => "1" },
          { "key" => "per", "value" => "10" },
        ],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result[:status]).to eq(200)
    end

    it "merges query parameters with existing ones in URL" do
      stub_request(:get, "https://api.example.com/data?existing=true&extra=yes").to_return(
        status: 200,
        body: "{}",
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "GET",
        "url" => "https://api.example.com/data?existing=true",
        "query_params" => [{ "key" => "extra", "value" => "yes" }],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result[:status]).to eq(200)
    end

    it "sends custom headers" do
      stub_request(:get, "https://api.example.com/data").with(
        headers: {
          "X-Api-Key" => "secret123",
        },
      ).to_return(status: 200, body: "{}", headers: { "content-type" => "application/json" })

      config = {
        "method" => "GET",
        "url" => "https://api.example.com/data",
        "headers" => [{ "key" => "X-Api-Key", "value" => "secret123" }],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result[:status]).to eq(200)
    end

    it "sends a JSON body with POST requests" do
      stub_request(:post, "https://api.example.com/data").with(body: '{"name":"test"}').to_return(
        status: 201,
        body: { id: 1 }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "POST",
        "url" => "https://api.example.com/data",
        "body" => '{"name":"test"}',
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result[:status]).to eq(201)
      expect(result[:body]).to eq("id" => 1)
    end

    it "raises an error for non-2xx status codes" do
      stub_request(:get, "https://api.example.com/fail").to_return(status: 404, body: "Not Found")

      config = { "method" => "GET", "url" => "https://api.example.com/fail" }

      expect { action.execute_single(context, item: item, config: config) }.to raise_error(
        RuntimeError,
        /HTTP request failed with status 404/,
      )
    end

    it "raises an error for server errors" do
      stub_request(:post, "https://api.example.com/error").to_return(
        status: 500,
        body: "Internal Server Error",
      )

      config = { "method" => "POST", "url" => "https://api.example.com/error", "body" => "{}" }

      expect { action.execute_single(context, item: item, config: config) }.to raise_error(
        RuntimeError,
        /HTTP request failed with status 500/,
      )
    end

    it "returns non-JSON responses wrapped in a data key" do
      stub_request(:get, "https://example.com/page").to_return(
        status: 200,
        body: "<html>hello</html>",
        headers: {
          "content-type" => "text/html",
        },
      )

      config = { "method" => "GET", "url" => "https://example.com/page" }
      result = action.execute_single(context, item: item, config: config)

      expect(result[:body]).to eq("data" => "<html>hello</html>")
    end

    it "records request details in logs" do
      stub_request(:post, "https://api.example.com/data").to_return(
        status: 200,
        body: { ok: true }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "POST",
        "url" => "https://api.example.com/data",
        "headers" => [{ "key" => "Authorization", "value" => "Bearer tok" }],
        "body" => '{"name":"test"}',
      }

      action.execute_single(context, item: item, config: config)

      expect(action.logs).to eq(
        [
          "POST https://api.example.com/data",
          "Authorization: [FILTERED]",
          "Content-Type: application/json",
          '{"name":"test"}',
        ],
      )
    end

    it "raises when URL is blank" do
      config = { "method" => "GET", "url" => "" }

      expect { action.execute_single(context, item: item, config: config) }.to raise_error(
        RuntimeError,
        "URL is required",
      )
    end
  end
end
