# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Oauth2Connection do
  fab!(:credential, :discourse_workflows_oauth2_credential)

  let(:url) { "https://api.example.com/contacts" }
  let(:token_response) { { access_token: "new-access", token_type: "Bearer", expires_in: 3600 } }

  describe "#authorization_header" do
    it "authenticates automatically and caches the token until expiry" do
      freeze_time
      authentication =
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: token_response.to_json,
        )

      expect(described_class.new(credential).authorization_header(url)).to eq("Bearer new-access")
      expect(described_class.new(credential).authorization_header(url)).to eq("Bearer new-access")
      expect(authentication).to have_been_requested.once
      expect(credential.reload.oauth_connection).to include(
        "status" => "connected",
        "expires_at" => 1.hour.from_now.to_i,
      )
      expect(credential.data.to_json).not_to include(
        token_response[:access_token],
        credential.oauth_client_secret,
      )

      freeze_time 1.hour.from_now
      expect(described_class.new(credential).authorization_header(url)).to eq("Bearer new-access")
      expect(authentication).to have_been_requested.twice
    end

    it "rejects requests to another origin" do
      stub_request(:post, "https://auth.example.com/token").to_return(
        status: 200,
        body: token_response.to_json,
      )
      %w[
        https://other.example.com/contacts
        http://api.example.com/contacts
        https://api.example.com:8443/contacts
        https://user@api.example.com/contacts
      ].each do |unsafe_url|
        expect { described_class.new(credential).authorization_header(unsafe_url) }.to raise_error(
          DiscourseWorkflows::NodeError,
        )
      end
    end
  end

  describe "#refresh_authorization" do
    it "reuses another worker's newly acquired token" do
      credential.oauth_connection = {
        "grant_type" => "client_credentials",
        "status" => "connected",
        "access_token" => "old-access",
      }
      credential.save!
      stale_worker = described_class.new(DiscourseWorkflows::Credential.find(credential.id))
      authentication =
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: token_response.to_json,
        )

      expect(
        described_class.new(credential).refresh_authorization(
          url,
          rejected_header: "Bearer old-access",
        ),
      ).to eq("Bearer new-access")
      expect(stale_worker.refresh_authorization(url, rejected_header: "Bearer old-access")).to eq(
        "Bearer new-access",
      )
      expect(authentication).to have_been_requested.once
    end
  end

  describe "a provider that omits expires_in" do
    let(:undated_tokens) { { access_token: "new-access", token_type: "Bearer" } }

    it "never expires the cached token without an assumed lifetime" do
      stub_request(:post, "https://auth.example.com/token").to_return(
        status: 200,
        body: undated_tokens.to_json,
      )

      described_class.new(credential).authorization_header(url)

      expect(credential.reload.oauth_connection["expires_at"]).to be_nil
    end

    it "renews ahead of the assumed lifetime so a request never carries a stale token" do
      credential.merge_data("token_lifetime" => "3600")
      credential.save!
      authentication =
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: undated_tokens.to_json,
        )
      start = Time.now

      freeze_time(start) do
        described_class.new(credential).authorization_header(url)
        expect(credential.reload.oauth_connection["expires_at"]).to eq(start.to_i + 3600)
      end

      # Still inside the window: the cached token is reused.
      freeze_time(start + 30.minutes) { described_class.new(credential).authorization_header(url) }
      expect(authentication).to have_been_requested.once

      # Past it: renewed before the request goes out, with no 401 involved.
      freeze_time(start + 2.hours) { described_class.new(credential).authorization_header(url) }
      expect(authentication).to have_been_requested.twice
    end

    it "prefers the provider's own expiry over the assumed one" do
      freeze_time
      credential.merge_data("token_lifetime" => "3600")
      credential.save!
      stub_request(:post, "https://auth.example.com/token").to_return(
        status: 200,
        body: undated_tokens.merge(expires_in: 120).to_json,
      )

      described_class.new(credential).authorization_header(url)

      expect(credential.reload.oauth_connection["expires_at"]).to eq(Time.now.to_i + 120)
    end
  end

  describe "#reject_authorization" do
    it "does not disconnect a newer token when an older in-flight request fails" do
      credential.oauth_connection = {
        "grant_type" => "client_credentials",
        "status" => "connected",
        "access_token" => "new-access",
      }
      credential.save!

      expect {
        described_class.new(credential).reject_authorization(rejected_header: "Bearer old-access")
      }.to raise_error(DiscourseWorkflows::NodeError)
      expect(credential.reload.oauth_connection["status"]).to eq("connected")
    end
  end

  it "fails safely when encrypted token data cannot be decrypted" do
    credential.update_column(:data, credential.data.merge("_oauth2" => "corrupted"))

    expect { described_class.new(credential).authorization_header(url) }.to raise_error(
      DiscourseWorkflows::NodeError,
    )
  end
end
