# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhookRequestParser do
  let(:body) { "" }
  let(:content_type) { "application/json" }
  let(:content_length) { body.bytesize }
  let(:request_env) do
    {
      "CONTENT_TYPE" => content_type,
      "CONTENT_LENGTH" => content_length.to_s,
      "HTTP_ACCEPT" => "application/json",
      "HTTP_X_CUSTOM" => "custom-value",
      "HTTP_AUTHORIZATION" => "Bearer secret",
      "HTTP_COOKIE" => "session=abc",
      "SERVER_NAME" => "localhost",
    }
  end
  let(:headers) { instance_double(ActionDispatch::Http::Headers, env: request_env) }
  let(:request) do
    instance_double(
      ActionDispatch::Request,
      content_type: content_type,
      content_length: content_length,
      raw_post: body,
      headers: headers,
    )
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
  let(:parser) { described_class.new(request, params) }

  describe "#parse_body" do
    context "with a valid JSON body" do
      let(:body) { '{"foo": "bar"}' }

      it "parses the body" do
        expect(parser.parse_body).to eq("foo" => "bar")
      end
    end

    context "with an empty JSON object" do
      let(:body) { "{}" }

      it "returns an empty hash" do
        expect(parser.parse_body).to eq({})
      end
    end

    context "with invalid JSON" do
      let(:body) { "not json{" }

      it "raises an invalid parameters error" do
        expect { parser.parse_body }.to raise_error(Discourse::InvalidParameters, /Invalid JSON/)
      end
    end

    context "with a non-JSON content type" do
      let(:body) { "data=test" }
      let(:content_type) { "application/x-www-form-urlencoded" }

      it "falls back to filtered params" do
        result = parser.parse_body
        expect(result).to eq("data" => "test")
        expect(result).not_to have_key("path")
        expect(result).not_to have_key("listener_id")
      end
    end

    context "when content length exceeds the maximum" do
      let(:body) { "x" }
      let(:content_length) { 2.megabytes }

      it "raises an invalid parameters error" do
        expect { parser.parse_body }.to raise_error(
          Discourse::InvalidParameters,
          /Request body too large/,
        )
      end
    end

    context "when the raw body exceeds the maximum" do
      let(:body) { "x" * (1.megabyte + 1) }
      let(:content_length) { 100 }

      it "raises an invalid parameters error" do
        expect { parser.parse_body }.to raise_error(
          Discourse::InvalidParameters,
          /Request body too large/,
        )
      end
    end
  end

  describe "#extract_headers" do
    it "extracts HTTP_ prefixed headers as lowercase dashed names" do
      headers = parser.extract_headers

      expect(headers["accept"]).to eq("application/json")
      expect(headers["x-custom"]).to eq("custom-value")
    end

    it "includes unprefixed content-type and content-length" do
      headers = parser.extract_headers

      expect(headers["content-type"]).to eq("application/json")
    end

    it "filters sensitive headers" do
      headers = parser.extract_headers

      expect(headers["authorization"]).to eq("[FILTERED]")
      expect(headers["cookie"]).to eq("[FILTERED]")
    end

    it "skips non-HTTP rack variables" do
      headers = parser.extract_headers

      expect(headers).not_to have_key("SERVER_NAME")
      expect(headers).not_to have_key("server-name")
    end
  end
end
