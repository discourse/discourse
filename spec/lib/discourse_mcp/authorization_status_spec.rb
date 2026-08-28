# frozen_string_literal: true

describe DiscourseMcp::AuthorizationStatus do
  fab!(:user)
  fab!(:group)
  fab!(:other_group, :group)

  let(:client) do
    McpOauthClient.create!(
      client_id: "authorization-status-spec-client",
      name: "Authorization status spec client",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end
  let(:authorization) do
    DiscourseMcp::OAuth::AuthorizationGrant.create!(
      user: user,
      client: client,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: %w[mcp:profile:read mcp:content:read],
    )
  end

  before do
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    other_group.add(user)
    McpGroupScope.create!(group: group, scope: "mcp:profile:read")
    McpGroupScope.create!(group: group, scope: "mcp:content:read")
    McpGroupScope.create!(group: other_group, scope: "mcp:content:read")
  end

  it "keeps access active while any group provides every granted scope" do
    McpGroupScope.where(group: other_group, scope: "mcp:content:read").delete_all

    expect(described_class.for([authorization])).to eq(authorization.id => "active")

    McpGroupScope.where(group: group, scope: "mcp:content:read").delete_all

    expect(described_class.for([authorization])).to eq(authorization.id => "access_removed")
  end

  it "reports the current server, client, and user restriction" do
    authorization
    SiteSetting.mcp_server_enabled = false
    expect(described_class.for([authorization])).to eq(authorization.id => "server_disabled")

    SiteSetting.mcp_server_enabled = true
    client.update!(trust_state: "blocked")
    expect(described_class.for([authorization])).to eq(authorization.id => "client_blocked")

    client.update!(trust_state: "pending")
    expect(described_class.for([authorization])).to eq(authorization.id => "client_not_approved")

    client.update!(trust_state: "approved")
    user.update!(active: false)
    expect(described_class.for([authorization])).to eq(authorization.id => "user_unavailable")
  end

  it "reports when fresh consent is required or access was revoked" do
    authorization
    client.update!(metadata_hash: "changed")
    expect(described_class.for([authorization])).to eq(authorization.id => "consent_required")

    authorization.revoke!(by_user: user)
    expect(described_class.for([authorization])).to eq(authorization.id => "revoked")
  end

  it "ignores fresh consent requirements for primitives outside the granted scopes" do
    McpPrimitive.create!(
      kind: "tool",
      identifier: "discourse.post.set_deleted",
      enabled: true,
      consent_required_at: 1.second.from_now,
    )

    expect(described_class.for([authorization])).to eq(authorization.id => "active")
  end
end
