# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::OAuthFlow do
  fab!(:user)
  fab!(:oauth_client_secret, :ai_secret)
  fab!(:ai_mcp_server) { Fabricate(:ai_mcp_server, auth_type: "oauth") }

  before do
    enable_current_plugin
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
  end

  describe ".start!" do
    it "rejects insecure Discourse site URLs before starting OAuth" do
      Discourse.stubs(:base_url).returns("http://mcp.home.arpa")

      expect { described_class.start!(server: ai_mcp_server, user: user) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        I18n.t("discourse_ai.mcp_servers.errors.oauth_https_required"),
      )
    end
  end

  describe ".refresh!" do
    it "uses HTTP basic auth without sending client_secret in the request body" do
      ai_mcp_server.update!(
        oauth_client_registration: "manual",
        oauth_client_id: "client-id",
        oauth_client_secret_ai_secret_id: oauth_client_secret.id,
      )
      ai_mcp_server.oauth_token_store.write!(
        access_token: "expired-access-token",
        refresh_token: "refresh-token",
      )
      ai_mcp_server.stubs(:oauth_discovery_result).returns(
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
        ),
      )

      stub_request(:post, "https://auth.example.com/token")
        .with do |request|
          decoded_body = Rack::Utils.parse_nested_query(request.body)
          request.headers["Authorization"] ==
            "Basic #{Base64.strict_encode64("client-id:#{oauth_client_secret.secret}")}" &&
            decoded_body["refresh_token"] == "refresh-token" && !decoded_body.key?("client_secret")
        end
        .to_return(
          status: 200,
          body: {
            access_token: "fresh-access-token",
            refresh_token: "fresh-refresh-token",
            token_type: "Bearer",
          }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      described_class.refresh!(ai_mcp_server)

      expect(ai_mcp_server.reload.oauth_token.access_token).to eq("fresh-access-token")
      expect(ai_mcp_server.oauth_token.refresh_token).to eq("fresh-refresh-token")
    end
  end
end
