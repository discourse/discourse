# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::OAuthClientRegistration do
  fab!(:ai_mcp_server) { Fabricate(:ai_mcp_server, auth_type: "oauth") }

  before do
    enable_current_plugin
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
  end

  let(:registration_endpoint) { "https://auth.example.com/register" }

  let(:discovery) do
    DiscourseAi::Mcp::OAuthDiscovery::Result.new(
      resource: ai_mcp_server.url,
      resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
      issuer: "https://auth.example.com",
      authorization_endpoint: "https://auth.example.com/authorize",
      token_endpoint: "https://auth.example.com/token",
      revocation_endpoint: nil,
      registration_endpoint: registration_endpoint,
    )
  end

  describe ".register!" do
    it "sends client metadata and stores the returned client_id" do
      stub_request(:post, registration_endpoint).to_return(
        status: 201,
        body: { client_id: "dynamic-client-id-123" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      result = described_class.register!(server: ai_mcp_server, discovery: discovery)

      expect(result["client_id"]).to eq("dynamic-client-id-123")
      expect(ai_mcp_server.reload.oauth_client_id).to eq("dynamic-client-id-123")

      expect(
        a_request(:post, registration_endpoint).with do |request|
          body = JSON.parse(request.body)
          body["redirect_uris"] == [ai_mcp_server.oauth_callback_url] &&
            body["grant_types"] == %w[authorization_code refresh_token] &&
            body["response_types"] == ["code"] && body["token_endpoint_auth_method"] == "none"
        end,
      ).to have_been_made.once
    end

    it "stores a dynamically issued client_secret" do
      stub_request(:post, registration_endpoint).to_return(
        status: 201,
        body: { client_id: "dynamic-client-id", client_secret: "dynamic-secret-value" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      described_class.register!(server: ai_mcp_server, discovery: discovery)

      ai_mcp_server.reload
      expect(ai_mcp_server.oauth_client_id).to eq("dynamic-client-id")
      expect(ai_mcp_server.oauth_client_secret_value).to eq("dynamic-secret-value")
    end

    it "includes scope when configured on the server" do
      ai_mcp_server.update_columns(oauth_scopes: "read write")

      stub_request(:post, registration_endpoint).to_return(
        status: 201,
        body: { client_id: "scoped-client" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      described_class.register!(server: ai_mcp_server, discovery: discovery)

      expect(
        a_request(:post, registration_endpoint).with do |request|
          JSON.parse(request.body)["scope"] == "read write"
        end,
      ).to have_been_made.once
    end

    it "raises when the registration endpoint returns an error" do
      stub_request(:post, registration_endpoint).to_return(
        status: 400,
        body: {
          error: "invalid_client_metadata",
          error_description: "Invalid redirect URI",
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect {
        described_class.register!(server: ai_mcp_server, discovery: discovery)
      }.to raise_error(DiscourseAi::Mcp::Client::Error, "Invalid redirect URI")
    end

    it "raises when no client_id is returned" do
      stub_request(:post, registration_endpoint).to_return(
        status: 201,
        body: { client_name: "test" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect {
        described_class.register!(server: ai_mcp_server, discovery: discovery)
      }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        I18n.t("discourse_ai.mcp_servers.errors.oauth_client_registration_failed_no_id"),
      )
    end

    it "raises when no registration_endpoint is in discovery" do
      discovery_without_reg =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
          registration_endpoint: nil,
        )

      expect {
        described_class.register!(server: ai_mcp_server, discovery: discovery_without_reg)
      }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        I18n.t("discourse_ai.mcp_servers.errors.oauth_registration_endpoint_missing"),
      )
    end
  end
end
