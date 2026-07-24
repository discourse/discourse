# frozen_string_literal: true

RSpec.describe Middleware::CspScriptNonceInjector do
  let(:env) { Rack::MockRequest.env_for("/") }
  let(:app) do
    lambda do |request_env|
      headers = {
        "Content-Security-Policy" => "script-src 'strict-dynamic'",
        "Content-Security-Policy-Report-Only" => "script-src 'strict-dynamic'",
      }
      nonce = ContentSecurityPolicy.nonce_placeholder(headers, request_env:)
      @app_body = ["<script nonce=\"#{nonce}\"></script>"]

      [200, headers, @app_body]
    end
  end
  let(:middleware) { described_class.new(app) }

  context "when the request cannot use the anonymous cache" do
    before { Middleware::AnonymousCache::Helper.any_instance.stubs(:cacheable?).returns(false) }

    it "renders the nonce directly without copying the response" do
      _status, headers, response_body = middleware.call(env)
      nonce = env[described_class::NONCE_ENV]

      expect(nonce).to match(/\A[A-Za-z0-9]{25}\z/)
      expect(response_body).to equal(@app_body)
      expect(response_body.join).to include(%(nonce="#{nonce}"))
      expect(headers["Content-Security-Policy"]).to include("'nonce-#{nonce}'")
      expect(headers["Content-Security-Policy-Report-Only"]).to include("'nonce-#{nonce}'")
      expect(headers).not_to include(described_class::PLACEHOLDER_HEADER)
    end
  end

  context "when the request can use the anonymous cache" do
    before { Middleware::AnonymousCache::Helper.any_instance.stubs(:cacheable?).returns(true) }

    it "replaces the placeholder after rendering" do
      _status, headers, response_body = middleware.call(env)
      nonce = headers["Content-Security-Policy"][/\A.*'nonce-([^']+)'/, 1]

      expect(env).not_to include(described_class::NONCE_ENV)
      expect(@app_body.join).to include("[[csp_nonce_placeholder_")
      expect(response_body).not_to equal(@app_body)
      expect(response_body.join).to include(%(nonce="#{nonce}"))
      expect(response_body.join).not_to include("[[csp_nonce_placeholder_")
      expect(headers["Content-Security-Policy-Report-Only"]).to include("'nonce-#{nonce}'")
      expect(headers).not_to include(described_class::PLACEHOLDER_HEADER)
    end
  end
end
