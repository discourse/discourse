# frozen_string_literal: true

describe Admin::McpAuthorizationsController do
  fab!(:admin)
  fab!(:user)
  fab!(:group)

  before do
    sign_in(admin)
    SiteSetting.mcp_server_enabled = true
    group.add(user)
  end

  it "returns the effective authorization status" do
    McpGroupScope.create!(group: group, scope: "mcp:profile:read")
    client =
      McpOauthClient.create!(
        client_id: "admin-authorizations-spec-client",
        name: "Admin authorizations spec client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    DiscourseMcp::OAuth::AuthorizationGrant.create!(
      user: user,
      client: client,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: ["mcp:profile:read"],
    )
    SiteSetting.mcp_server_enabled = false

    get "/admin/mcp/authorizations.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("authorizations", 0, "status")).to eq("server_disabled")
  end
end
