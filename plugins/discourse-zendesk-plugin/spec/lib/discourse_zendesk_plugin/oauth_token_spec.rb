# frozen_string_literal: true

RSpec.describe DiscourseZendeskPlugin::OAuthToken do
  subject(:oauth_token) { described_class.new }

  let(:token_url) { "https://your-url.zendesk.com/oauth/tokens" }

  before do
    SiteSetting.zendesk_url = "https://your-url.zendesk.com/api/v2"
    SiteSetting.zendesk_oauth_client_id = "oauth-client-id"
    SiteSetting.zendesk_oauth_client_secret = "oauth-client-secret"
  end

  describe "#access_token" do
    it "requests and caches a scoped short-lived token" do
      token_request =
        stub_request(:post, token_url).with(
          body: {
            "client_id" => "oauth-client-id",
            "client_secret" => "oauth-client-secret",
            "expires_in" => "1800",
            "grant_type" => "client_credentials",
            "scope" => "tickets:read tickets:write users:read users:write",
          },
        ).to_return(
          status: 200,
          body: { access_token: "access-token", expires_in: 1800 }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      expect(oauth_token.access_token).to eq("access-token")
      expect(oauth_token.access_token).to eq("access-token")
      expect(token_request).to have_been_requested.once
    end

    it "uses a new cache entry after credential rotation" do
      token_request =
        stub_request(:post, token_url).to_return(
          { status: 200, body: { access_token: "first-token", expires_in: 1800 }.to_json },
          { status: 200, body: { access_token: "rotated-token", expires_in: 1800 }.to_json },
        )

      expect(oauth_token.access_token).to eq("first-token")

      SiteSetting.zendesk_oauth_client_secret = "rotated-secret"

      expect(described_class.new.access_token).to eq("rotated-token")
      expect(token_request).to have_been_requested.twice
    end

    it "does not cache an in-flight token under rotated credentials" do
      request_count = 0
      token_request =
        stub_request(:post, token_url).to_return do
          request_count += 1

          if request_count == 1
            SiteSetting.zendesk_oauth_client_secret = "rotated-secret"
            { status: 200, body: { access_token: "first-token", expires_in: 1800 }.to_json }
          else
            { status: 200, body: { access_token: "rotated-token", expires_in: 1800 }.to_json }
          end
        end

      expect(oauth_token.access_token).to eq("first-token")
      expect(described_class.new.access_token).to eq("rotated-token")
      expect(token_request).to have_been_requested.twice
    end

    it "rejects an insecure Zendesk URL before sending credentials" do
      SiteSetting.zendesk_url = "http://your-url.zendesk.com/api/v2"

      expect { oauth_token.access_token }.to raise_error(
        described_class::RequestError,
        "Zendesk OAuth requires an HTTPS URL",
      )
      expect(WebMock).not_to have_requested(:post, %r{/oauth/tokens})
    end

    it "rejects an unsuccessful token response without exposing its body" do
      stub_request(:post, token_url).to_return(status: 401, body: "oauth-client-secret")

      expect { oauth_token.access_token }.to raise_error(
        described_class::RequestError,
        "Zendesk OAuth token request failed",
      )
    end

    it "rejects a malformed token response" do
      stub_request(:post, token_url).to_return(status: 200, body: { expires_in: 1800 }.to_json)

      expect { oauth_token.access_token }.to raise_error(
        described_class::RequestError,
        "Zendesk OAuth token response is invalid",
      )
    end
  end

  describe "#invalidate" do
    it "forces the next operation to request a new token" do
      token_request =
        stub_request(:post, token_url).to_return(
          { status: 200, body: { access_token: "first-token", expires_in: 1800 }.to_json },
          { status: 200, body: { access_token: "second-token", expires_in: 1800 }.to_json },
        )

      expect(oauth_token.access_token).to eq("first-token")

      oauth_token.invalidate

      expect(oauth_token.access_token).to eq("second-token")
      expect(token_request).to have_been_requested.twice
    end
  end
end
