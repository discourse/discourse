# frozen_string_literal: true
RSpec.describe Middleware::DefaultHeaders do
  let(:mock_default_headers) do
    {
      "X-XSS-Protection" => "0",
      "X-Content-Type-Options" => "nosniff",
      "X-Permitted-Cross-Domain-Policies" => "none",
      "Referrer-Policy" => "strict-origin-when-cross-origin",
    }
  end

  let(:html_only_headers) { described_class::HTML_ONLY_HEADERS }
  let(:universal_headers) { Set.new(mock_default_headers.keys) - html_only_headers }

  before do
    allow(Rails.application.config.action_dispatch).to receive(:default_headers).and_return(
      mock_default_headers,
    )
  end

  context "when a public exception(like RoutingError) is raised" do
    context "when requesting an HTML page" do
      let(:html_path) { "/nonexistent" }

      it "sets the Cross-Origin-Opener-Policy header" do
        SiteSetting.bootstrap_error_pages = true
        get html_path # triggers a RoutingError, handled by the exceptions_app
        expect(response.headers).to have_key("Cross-Origin-Opener-Policy")
        expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin-allow-popups")
      end

      it "sets all default Rails headers for HTML responses" do
        get html_path

        mock_default_headers.each { |name, value| expect(response.headers[name]).to eq(value) }
      end
    end

    context "when requesting a JSON response for an invalid URL" do
      let(:json_path) { "/nonexistent.json" }

      it "adds only universal default headers to non-HTML responses" do
        get json_path

        universal_headers.each do |name|
          expect(response.headers[name]).to eq(mock_default_headers[name])
        end
        html_only_headers.each { |name| expect(response.headers[name]).to be_nil }
        expect(response.headers["Cross-Origin-Opener-Policy"]).to be_nil
      end
    end
  end

  context "when a rescued exception is raised" do
    let(:fake_logger) { FakeLogger.new }

    before { Rails.logger.broadcast_to(fake_logger) }

    after { Rails.logger.stop_broadcasting_to(fake_logger) }

    it "adds default headers to the response" do
      bad_str = (+"d\xDE").force_encoding("utf-8")
      expect(bad_str.valid_encoding?).to eq(false)

      get "/latest", params: { test: bad_str }

      expect(fake_logger.warnings.length).to eq(0)
      expect(response.status).to eq(400)
      expect(response.headers).to have_key("Cross-Origin-Opener-Policy")
      expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin-allow-popups")
      mock_default_headers.each { |name, value| expect(response.headers[name]).to eq(value) }
    end
  end
end
