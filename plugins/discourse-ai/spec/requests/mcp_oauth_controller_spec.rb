# frozen_string_literal: true

RSpec.describe DiscourseAi::McpOauthController do
  before { enable_current_plugin }

  describe "GET #client_metadata" do
    it "returns a client metadata document" do
      get "/discourse-ai/mcp/oauth/client-metadata.json"

      expect(response).to be_successful
      expect(response.parsed_body["client_name"]).to eq("Discourse AI MCP Client")
      expect(response.parsed_body["redirect_uris"]).to include(
        "#{Discourse.base_url}/admin/plugins/discourse-ai/ai-mcp-servers/oauth/callback",
      )
      expect(response.parsed_body["grant_types"]).to eq(%w[authorization_code refresh_token])
      expect(response.parsed_body["token_endpoint_auth_method"]).to eq("none")
    end
  end
end
