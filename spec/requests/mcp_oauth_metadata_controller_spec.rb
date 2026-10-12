# frozen_string_literal: true

describe McpOauthMetadataController do
  before { SiteSetting.mcp_server_enabled = true }

  %w[
    /.well-known/oauth-protected-resource/mcp
    /.well-known/oauth-authorization-server
    /.well-known/openid-configuration
  ].each do |endpoint|
    context "when login is required for #{endpoint}" do
      before { SiteSetting.login_required = true }

      it "returns discovery metadata without a browser session" do
        get endpoint, headers: { "Accept" => "application/json" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["scopes_supported"]).to eq(DiscourseMcp.registry.scopes)
      end

      it "returns not found when MCP is disabled" do
        SiteSetting.mcp_server_enabled = false

        get endpoint, headers: { "Accept" => "application/json" }

        expect(response.status).to eq(404)
      end
    end
  end

  it "advertises every registered scope in protected resource metadata" do
    get "/.well-known/oauth-protected-resource/mcp"

    expect(response.status).to eq(200)
    expect(response.parsed_body["scopes_supported"]).to eq(DiscourseMcp.registry.scopes)
  end

  it "advertises every registered scope in authorization server metadata" do
    get "/.well-known/oauth-authorization-server"

    expect(response.status).to eq(200)
    expect(response.parsed_body["scopes_supported"]).to eq(DiscourseMcp.registry.scopes)
  end

  it "advertises client ID metadata documents by default" do
    get "/.well-known/oauth-authorization-server"

    expect(response.status).to eq(200)
    expect(response.parsed_body["client_id_metadata_document_supported"]).to eq(true)
  end

  it "does not advertise client ID metadata documents when clients must be pre-registered" do
    SiteSetting.mcp_oauth_client_id_metadata_policy = "disabled"

    get "/.well-known/oauth-authorization-server"

    expect(response.status).to eq(200)
    expect(response.parsed_body["client_id_metadata_document_supported"]).to eq(false)
  end

  it "advertises client ID metadata documents when approved domains may register clients" do
    SiteSetting.mcp_oauth_client_id_metadata_policy = "approved_domains"

    get "/.well-known/oauth-authorization-server"

    expect(response.status).to eq(200)
    expect(response.parsed_body["client_id_metadata_document_supported"]).to eq(true)
  end
end
