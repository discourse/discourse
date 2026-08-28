# frozen_string_literal: true

describe McpOauthAuthorizationsController do
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.mcp_server_enabled = true
  end

  it "labels the OAuth resource as the MCP server" do
    client =
      McpOauthClient.create!(
        client_id: "consent-page-client",
        name: "Consent page client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )

    get "/oauth2/mcp/authorize",
        params: {
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          response_type: "code",
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          resource: DiscourseMcp.resource_url,
          scope: "mcp:profile:read mcp:content:read",
        }

    expect(response.status).to eq(200)
    labels = Nokogiri.HTML5(response.body).css("dt").map(&:text)
    expect(labels).to include(I18n.t("mcp.oauth.resource"))
  end

  it "rejects an authorization request without the initial scope" do
    client =
      McpOauthClient.create!(
        client_id: "missing-initial-scope-client",
        name: "Missing initial scope client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )

    get "/oauth2/mcp/authorize",
        params: {
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          response_type: "code",
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          resource: DiscourseMcp.resource_url,
          scope: "mcp:content:read",
        }

    expect(response.status).to eq(403)
  end
end
