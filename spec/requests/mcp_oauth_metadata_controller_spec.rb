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

  it "does not advertise client ID metadata documents when clients must be pre-registered" do
    SiteSetting.mcp_oauth_client_trust_policy = "pre_registered"

    get "/.well-known/oauth-authorization-server"

    expect(response.status).to eq(200)
    expect(response.parsed_body["client_id_metadata_document_supported"]).to eq(false)
  end

  it "advertises client ID metadata documents when approved domains may register clients" do
    SiteSetting.mcp_oauth_client_trust_policy = "approved_domains"

    get "/.well-known/oauth-authorization-server"

    expect(response.status).to eq(200)
    expect(response.parsed_body["client_id_metadata_document_supported"]).to eq(true)
  end
end
