# frozen_string_literal: true

describe McpOauthMetadataController do
  before { SiteSetting.mcp_server_enabled = true }

  it "advertises the initial scope in protected resource metadata" do
    get "/.well-known/oauth-protected-resource/mcp"

    expect(response.status).to eq(200)
    expect(response.parsed_body["scopes_supported"]).to eq(["mcp:profile:read"])
  end

  it "advertises every registered scope in authorization server metadata" do
    get "/.well-known/oauth-authorization-server"

    expect(response.status).to eq(200)
    expect(response.parsed_body["scopes_supported"]).to eq(DiscourseMcp.registry.scopes)
  end
end
