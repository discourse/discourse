# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Oauth2Provider do
  fab!(:credential, :discourse_workflows_oauth2_credential)

  describe "#authenticate" do
    it "sends client credentials and optional scope in a form body" do
      credential.merge_data("scope" => "contacts:write")
      credential.save!
      authentication =
        stub_request(:post, "https://auth.example.com/token").with(
          body: {
            grant_type: "client_credentials",
            client_id: "workflow-client",
            client_secret: "workflow-secret",
            scope: "contacts:write",
          },
        ).to_return(
          status: 200,
          body: { access_token: "access-token", token_type: "Bearer" }.to_json,
        )

      expect(described_class.new(credential).authenticate).to include(
        "access_token" => "access-token",
      )
      expect(authentication).to have_been_requested.once
    end

    it "supports HTTP Basic authentication without duplicating credentials in the body" do
      credential.merge_data(
        "token_auth_method" => "http_basic",
        "client_id" => "client:id",
        "client_secret" => "secret value",
      )
      credential.save!
      authentication =
        stub_request(:post, "https://auth.example.com/token").with(
          headers: {
            "Authorization" => "Basic #{Base64.strict_encode64("client%3Aid:secret+value")}",
          },
          body: {
            grant_type: "client_credentials",
          },
        ).to_return(
          status: 200,
          body: { access_token: "access-token", token_type: "bearer" }.to_json,
        )

      expect(described_class.new(credential).authenticate).to include(
        "access_token" => "access-token",
      )
      expect(authentication).to have_been_requested.once
    end

    it "rejects malformed responses and header injection" do
      [
        [],
        { access_token: "secret\r\nInjected: value", token_type: "Bearer" },
        { access_token: "secret", token_type: "MAC" },
      ].each do |response|
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: response.to_json,
        )

        expect { described_class.new(credential).authenticate }.to raise_error(
          described_class::Error,
        ) { |error| expect(error.code).to eq("invalid_response") }
      end
    end
  end

  describe "#validate_configuration" do
    it "requires a secure token endpoint and a secure API origin" do
      [
        { "token_url" => "http://auth.example.com/token" },
        { "token_url" => "https://user:secret@auth.example.com/token" },
        { "api_origin" => "https://api.example.com/path" },
        { "api_origin" => "https://api.example.com?query=value" },
        { "token_auth_method" => "unsupported" },
        { "revoke_url" => "http://auth.example.com/revoke" },
      ].each do |invalid_data|
        credential.merge_data(invalid_data)
        expect(credential).to be_invalid
        credential.reload
      end
    end

    it "accepts derived endpoints without endpoint fields in credential data" do
      provider_class =
        Class.new(described_class) do
          def token_url
            "#{@credential.data.fetch("api_origin")}/oauth/token"
          end

          def revoke_url
            "#{@credential.data.fetch("api_origin")}/oauth/revoke"
          end
        end
      credential.data = credential.data.except("token_url", "revoke_url")

      provider_class.new(credential).validate_configuration(credential)

      expect(credential.errors).to be_empty
    end

    it "rejects invalid derived endpoints even when configured endpoints are secure" do
      credential.data = credential.data.merge("revoke_url" => "https://auth.example.com/revoke")

      %i[token_url revoke_url].each do |endpoint|
        [
          "http://auth.example.com/oauth",
          "https://user:secret@auth.example.com/oauth",
          "invalid URL",
        ].each do |invalid_url|
          provider_class = Class.new(described_class) { define_method(endpoint) { invalid_url } }
          credential.errors.clear

          provider_class.new(credential).validate_configuration(credential)

          expect(credential.errors[:data]).to include(
            I18n.t("discourse_workflows.oauth2.errors.invalid_configuration"),
          )
        end
      end
    end

    it "reports a missing token endpoint as a configuration error" do
      credential.update_column(:data, credential.data.except("token_url"))

      expect { described_class.new(credential.reload).authenticate }.to raise_error(
        described_class::Error,
      ) { |error| expect(error.code).to eq("invalid_configuration") }
    end

    it "rejects an unusable assumed token lifetime" do
      ["0", "-60", "not a number", (25 * 3600).to_s].each do |invalid|
        credential.merge_data("token_lifetime" => invalid)
        expect(credential).to be_invalid
        credential.reload
      end
    end

    it "accepts a blank revocation endpoint" do
      credential.merge_data("revoke_url" => "")
      expect(credential).to be_valid
    end
  end

  describe "#revoke" do
    it "does nothing without a configured revocation endpoint" do
      expect(described_class.new(credential).revoke("access-token")).to be_nil
    end

    it "sends client credentials in the revocation form without token exchange parameters" do
      credential.merge_data(
        "revoke_url" => "https://auth.example.com/revoke",
        "scope" => "contacts:write",
      )
      credential.save!
      revocation =
        stub_request(:post, "https://auth.example.com/revoke").with(
          body: {
            token: "access-token",
            client_id: "workflow-client",
            client_secret: "workflow-secret",
          },
        ).to_return(status: 200, body: "")

      described_class.new(credential).revoke("access-token")

      expect(revocation).to have_been_requested.once
    end

    it "authenticates revocation with HTTP Basic without credentials in the body" do
      credential.merge_data(
        "revoke_url" => "https://auth.example.com/revoke",
        "token_auth_method" => "http_basic",
        "client_id" => "client:id",
        "client_secret" => "secret value",
        "scope" => "contacts:write",
      )
      credential.save!
      revocation =
        stub_request(:post, "https://auth.example.com/revoke").with(
          headers: {
            "Authorization" => "Basic #{Base64.strict_encode64("client%3Aid:secret+value")}",
          },
          body: {
            token: "access-token",
          },
        ).to_return(status: 200)

      described_class.new(credential).revoke("access-token")

      expect(revocation).to have_been_requested.once
    end

    it "treats an already revoked token as revoked and other failures as errors" do
      credential.merge_data("revoke_url" => "https://auth.example.com/revoke")
      credential.save!

      stub_request(:post, "https://auth.example.com/revoke").to_return(
        status: 400,
        body: { error: "invalid_token" }.to_json,
      )
      expect { described_class.new(credential).revoke("access-token") }.not_to raise_error

      stub_request(:post, "https://auth.example.com/revoke").to_return(status: 500, body: "")
      expect { described_class.new(credential).revoke("access-token") }.to raise_error(
        described_class::Error,
      ) { |error| expect(error.code).to eq("revocation_failed") }
    end
  end
end
