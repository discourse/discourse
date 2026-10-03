# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Oauth2Connection do
  fab!(:credential, :discourse_workflows_oauth2_credential)

  let(:url) { "https://api.example.com/contacts" }
  let(:token_response) { { access_token: "new-access", token_type: "Bearer", expires_in: 3600 } }

  describe "#connect" do
    it "replaces unreadable cached tokens when the administrator reconnects" do
      credential.merge_data("revoke_url" => "https://auth.example.com/revoke")
      credential.save!
      credential.update_column(:data, credential.data.merge("_oauth2" => "corrupted"))
      authentication =
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: token_response.to_json,
        )

      described_class.new(credential).connect

      expect(authentication).to have_been_requested.once
      expect(credential.reload.oauth_connection).to include(
        "status" => "connected",
        "access_token" => "new-access",
      )
      expect(described_class.new(credential).authorization_header(url)).to eq("Bearer new-access")
    end

    it "clears unreadable cached tokens even when new authentication fails" do
      credential.update_column(:data, credential.data.merge("_oauth2" => "corrupted"))
      stub_request(:post, "https://auth.example.com/token").to_return(
        status: 401,
        body: { error: "invalid_client" }.to_json,
      )

      expect { described_class.new(credential).connect }.to raise_error(
        DiscourseWorkflows::Oauth2Provider::Error,
      )
      expect(credential.reload.oauth_connection).to be_empty
    end
  end

  describe "#destroy" do
    it "deletes credentials with unreadable cached tokens" do
      credential.merge_data("revoke_url" => "https://auth.example.com/revoke")
      credential.save!
      credential.update_column(:data, credential.data.merge("_oauth2" => "corrupted"))

      expect { described_class.new(credential).destroy }.to change {
        DiscourseWorkflows::Credential.exists?(credential.id)
      }.from(true).to(false)
    end
  end

  describe "revocation during explicit recovery" do
    before do
      credential.merge_data("revoke_url" => "https://auth.example.com/revoke")
      credential.oauth_connection = {
        "status" => "connected",
        "grant_type" => "client_credentials",
        "access_token" => "old-access",
      }
      credential.save!
    end

    it "keeps readable tokens when the provider rejects revocation" do
      original_data = credential.data.deep_dup
      stub_request(:post, "https://auth.example.com/revoke").to_return(status: 503)

      %i[connect destroy].each do |operation|
        expect { described_class.new(credential).public_send(operation) }.to raise_error(
          DiscourseWorkflows::Oauth2Provider::Error,
        )
        expect(credential.reload.data).to eq(original_data)
      end
    end

    it "keeps readable tokens when client credentials cannot be decrypted" do
      credential.update_column(
        :data,
        credential.data.merge("client_secret" => { "encrypted" => "corrupted" }),
      )
      original_data = credential.data.deep_dup

      %i[connect destroy].each do |operation|
        expect { described_class.new(credential).public_send(operation) }.to raise_error(
          DiscourseWorkflows::Oauth2Provider::Revoked,
        )
        expect(credential.reload.data).to eq(original_data)
      end
    end
  end

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

    [1, 30, 60, 3600].each do |lifetime|
      it "caches a #{lifetime}-second token until its refresh window" do
        freeze_time
        authentication =
          stub_request(:post, "https://auth.example.com/token").to_return(
            status: 200,
            body: token_response.merge(expires_in: lifetime).to_json,
          )
        refresh_after = { 1 => 1, 30 => 27, 60 => 54, 3600 => 3540 }.fetch(lifetime)
        start = Time.now

        2.times do
          expect(described_class.new(credential).authorization_header(url)).to eq(
            "Bearer new-access",
          )
        end
        expect(authentication).to have_been_requested.once

        freeze_time(start + refresh_after - 1)
        described_class.new(credential).authorization_header(url)
        expect(authentication).to have_been_requested.once

        freeze_time(start + refresh_after)
        2.times { described_class.new(credential).authorization_header(url) }
        expect(authentication).to have_been_requested.twice
      end
    end

    it "renews cached tokens that predate the refresh timestamp" do
      freeze_time
      credential.oauth_connection = {
        "status" => "connected",
        "grant_type" => "client_credentials",
        "access_token" => "old-access",
        "expires_at" => 30.seconds.from_now.to_i,
      }
      credential.save!
      authentication =
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: token_response.to_json,
        )

      expect(described_class.new(credential).authorization_header(url)).to eq("Bearer new-access")
      expect(authentication).to have_been_requested.once
    end

    it "rejects requests to another origin before acquiring a token" do
      authentication =
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
      expect(authentication).not_to have_been_requested
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

      freeze_time(start + 30.minutes) { described_class.new(credential).authorization_header(url) }
      expect(authentication).to have_been_requested.once

      freeze_time(start + 2.hours) { described_class.new(credential).authorization_header(url) }
      expect(authentication).to have_been_requested.twice
    end

    it "caches tokens with a short assumed lifetime until their refresh window" do
      freeze_time
      credential.merge_data("token_lifetime" => "30")
      credential.save!
      authentication =
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: undated_tokens.to_json,
        )
      start = Time.now

      described_class.new(credential).authorization_header(url)
      freeze_time(start + 26)
      described_class.new(credential).authorization_header(url)
      expect(authentication).to have_been_requested.once

      freeze_time(start + 27)
      described_class.new(credential).authorization_header(url)
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

  describe "#update" do
    it "revokes with the old client credentials before saving new authentication details" do
      credential.merge_data(
        "revoke_url" => "https://auth.example.com/revoke",
        "token_auth_method" => "http_basic",
      )
      credential.oauth_connection = {
        "status" => "connected",
        "grant_type" => "client_credentials",
        "access_token" => "old-access",
      }
      credential.save!
      revocation =
        stub_request(:post, "https://auth.example.com/revoke").with(
          headers: {
            "Authorization" => "Basic #{Base64.strict_encode64("workflow-client:workflow-secret")}",
          },
          body: {
            token: "old-access",
          },
        ).to_return(status: 200)

      described_class.new(credential).update(
        name: credential.name,
        data: {
          "client_id" => "new-client",
          "client_secret" => "new-secret",
          "token_auth_method" => "request_body",
        },
      )

      expect(revocation).to have_been_requested.once
      expect(credential.reload.oauth_connection).to be_empty
      expect(credential.oauth_client_secret).to eq("new-secret")
      expect(credential.data).to include(
        "client_id" => "new-client",
        "token_auth_method" => "request_body",
      )
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
