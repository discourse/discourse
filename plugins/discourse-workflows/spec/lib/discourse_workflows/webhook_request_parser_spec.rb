# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhookRequestParser do
  def build_request(
    body: "",
    content_type: "application/json",
    content_length: nil,
    env_overrides: {}
  )
    env = {
      "CONTENT_TYPE" => content_type,
      "CONTENT_LENGTH" => (content_length || body.bytesize).to_s,
      "HTTP_ACCEPT" => "application/json",
      "HTTP_X_CUSTOM" => "custom-value",
      "HTTP_AUTHORIZATION" => "Bearer secret",
      "HTTP_COOKIE" => "session=abc",
      "SERVER_NAME" => "localhost",
    }.merge(env_overrides)

    req = instance_double(ActionDispatch::Request)
    allow(req).to receive(:content_type).and_return(content_type)
    allow(req).to receive(:content_length).and_return(content_length || body.bytesize)
    allow(req).to receive(:raw_post).and_return(body)

    headers = instance_double(ActionDispatch::Http::Headers)
    allow(headers).to receive(:env).and_return(env)
    allow(req).to receive(:headers).and_return(headers)

    req
  end

  let(:params) do
    ActionController::Parameters.new(
      path: "my-hook",
      listener_id: "listener-1",
      controller: "webhooks",
      action: "receive",
      format: "json",
      data: "test",
    )
  end

  describe "#parse_body" do
    it "parses a valid JSON body" do
      request = build_request(body: '{"foo": "bar"}')
      parser = described_class.new(request, params)
      expect(parser.parse_body).to eq("foo" => "bar")
    end

    it "returns empty hash for empty JSON body" do
      request = build_request(body: "{}")
      parser = described_class.new(request, params)
      expect(parser.parse_body).to eq({})
    end

    it "raises on invalid JSON" do
      request = build_request(body: "not json{")
      parser = described_class.new(request, params)
      expect { parser.parse_body }.to raise_error(Discourse::InvalidParameters, /Invalid JSON/)
    end

    it "falls back to params for non-JSON content type" do
      request = build_request(body: "data=test", content_type: "application/x-www-form-urlencoded")
      parser = described_class.new(request, params)
      result = parser.parse_body
      expect(result).to eq("data" => "test")
      expect(result).not_to have_key("path")
      expect(result).not_to have_key("listener_id")
    end

    it "raises when content_length exceeds max" do
      request = build_request(body: "x", content_length: 2.megabytes)
      parser = described_class.new(request, params)
      expect { parser.parse_body }.to raise_error(
        Discourse::InvalidParameters,
        /Request body too large/,
      )
    end

    it "raises when raw_post exceeds max" do
      large_body = "x" * (1.megabyte + 1)
      request = build_request(body: large_body, content_length: 100)
      parser = described_class.new(request, params)
      expect { parser.parse_body }.to raise_error(
        Discourse::InvalidParameters,
        /Request body too large/,
      )
    end
  end

  describe "#extract_headers" do
    it "extracts HTTP_ prefixed headers as lowercase dashed names" do
      request = build_request
      parser = described_class.new(request, params)
      headers = parser.extract_headers

      expect(headers["accept"]).to eq("application/json")
      expect(headers["x-custom"]).to eq("custom-value")
    end

    it "includes unprefixed content-type and content-length" do
      request = build_request
      parser = described_class.new(request, params)
      headers = parser.extract_headers

      expect(headers["content-type"]).to eq("application/json")
    end

    it "filters sensitive headers" do
      request = build_request
      parser = described_class.new(request, params)
      headers = parser.extract_headers

      expect(headers["authorization"]).to eq("[FILTERED]")
      expect(headers["cookie"]).to eq("[FILTERED]")
    end

    it "skips non-HTTP rack variables" do
      request = build_request
      parser = described_class.new(request, params)
      headers = parser.extract_headers

      expect(headers).not_to have_key("SERVER_NAME")
      expect(headers).not_to have_key("server-name")
    end
  end
end
