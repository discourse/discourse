# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HttpRequest::Authenticator do
  describe ".apply" do
    it "does nothing when authentication is none" do
      headers = {}
      described_class.apply({ "authentication" => "none" }, headers)

      expect(headers).not_to have_key("Authorization")
    end

    it "does nothing when authentication is not specified" do
      headers = {}
      described_class.apply({}, headers)

      expect(headers).not_to have_key("Authorization")
    end

    it "raises when credential_id is missing for auth modes" do
      expect { described_class.apply({ "authentication" => "basic_auth" }, {}) }.to raise_error(
        ArgumentError,
        /credential_id is required/,
      )
    end

    context "with basic_auth" do
      fab!(:credential) do
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "basic_auth",
          data:
            DiscourseWorkflows::CredentialEncryptor.encrypt(
              { "user" => "api_user", "password" => "api_pass" },
            ),
        )
      end

      it "sets Authorization header with Base64 credentials" do
        headers = {}
        described_class.apply(
          { "authentication" => "basic_auth", "credential_id" => credential.id },
          headers,
        )

        expected = "Basic #{Base64.strict_encode64("api_user:api_pass")}"
        expect(headers["Authorization"]).to eq(expected)
      end
    end

    context "with bearer_token" do
      fab!(:credential) do
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "bearer_token",
          data: DiscourseWorkflows::CredentialEncryptor.encrypt({ "token" => "my-secret-token" }),
        )
      end

      it "sets Bearer Authorization header" do
        headers = {}
        described_class.apply(
          { "authentication" => "bearer_token", "credential_id" => credential.id },
          headers,
        )

        expect(headers["Authorization"]).to eq("Bearer my-secret-token")
      end
    end
  end
end
