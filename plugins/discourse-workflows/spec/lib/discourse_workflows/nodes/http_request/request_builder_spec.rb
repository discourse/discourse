# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HttpRequest::RequestBuilder do
  describe "#build" do
    it "builds a GET request with method, uri, headers, and nil body" do
      config = { "method" => "GET", "url" => "https://example.com/api" }
      method, uri, headers, body = described_class.new(config).build

      expect(method).to eq(:get)
      expect(uri.to_s).to eq("https://example.com/api")
      expect(headers).to eq({})
      expect(body).to be_nil
    end

    it "raises when URL is blank" do
      expect { described_class.new("method" => "GET", "url" => "").build }.to raise_error(
        DiscourseWorkflows::NodeError,
        "URL is required.",
      )
    end

    it "raises for non-HTTP schemes" do
      expect { described_class.new("url" => "ftp://example.com").build }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Only HTTP and HTTPS/,
      )
    end

    it "allows non-standard ports" do
      config = { "method" => "GET", "url" => "https://example.com:8443/api" }
      _, uri, _, _ = described_class.new(config).build

      expect(uri.port).to eq(8443)
    end

    it "appends query params to the URL" do
      config = {
        "method" => "GET",
        "url" => "https://example.com/api",
        "query_params" => [
          { "key" => "page", "value" => "1" },
          { "key" => "per", "value" => "10" },
        ],
      }
      _, uri, _, _ = described_class.new(config).build

      expect(uri.query).to include("page=1")
      expect(uri.query).to include("per=10")
    end

    it "merges query params with existing ones" do
      config = {
        "method" => "GET",
        "url" => "https://example.com/api?existing=true",
        "query_params" => [{ "key" => "extra", "value" => "yes" }],
      }
      _, uri, _, _ = described_class.new(config).build

      expect(uri.query).to include("existing=true")
      expect(uri.query).to include("extra=yes")
    end

    it "uses normalized headers" do
      config = {
        "method" => "GET",
        "url" => "https://example.com/api",
        "headers" => {
          "X-Custom" => "test",
          "Accept" => "application/json",
        },
      }
      _, _, headers, _ = described_class.new(config).build

      expect(headers).to include("X-Custom" => "test", "Accept" => "application/json")
    end

    it "sets Content-Type and returns body for POST requests" do
      config = {
        "method" => "POST",
        "url" => "https://example.com/api",
        "body_json" => '{"name":"test"}',
      }
      method, _, headers, body = described_class.new(config).build

      expect(method).to eq(:post)
      expect(headers["Content-Type"]).to eq("application/json")
      expect(body).to eq('{"name":"test"}')
    end

    it "does not set body for GET requests even if body is provided" do
      config = {
        "method" => "GET",
        "url" => "https://example.com/api",
        "body_json" => '{"name":"test"}',
      }
      _, _, _, body = described_class.new(config).build

      expect(body).to be_nil
    end

    it "defaults method to GET" do
      config = { "url" => "https://example.com/api" }
      method, _, _, _ = described_class.new(config).build

      expect(method).to eq(:get)
    end
  end
end
