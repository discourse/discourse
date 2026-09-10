# frozen_string_literal: true

describe McpUserAuthorizationsController do
  fab!(:user)
  fab!(:group)
  fab!(:other_group, :group)

  before do
    sign_in(user)
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    other_group.add(user)
  end

  it "returns access removed only after all matching groups lose a granted scope" do
    McpGroupScope.create!(group: group, scope: "mcp:profile:read")
    McpGroupScope.create!(group: other_group, scope: "mcp:profile:read")
    client =
      McpOauthClient.create!(
        client_id: "user-authorizations-spec-client",
        name: "User authorizations spec client",
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

    McpGroupScope.where(group: group).delete_all
    get "/u/#{user.username}/preferences/mcp-authorizations.json"
    expect(response.parsed_body.dig("authorizations", 0, "status")).to eq("active")

    McpGroupScope.where(group: other_group).delete_all
    get "/u/#{user.username}/preferences/mcp-authorizations.json"
    expect(response.parsed_body.dig("authorizations", 0, "status")).to eq("access_removed")
  end
end
