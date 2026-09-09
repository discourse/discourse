# frozen_string_literal: true

describe Admin::McpController do
  fab!(:admin)
  fab!(:moderator)

  before { sign_in(admin) }

  describe "#overview" do
    it "reports approved OAuth client registrations" do
      get "/admin/mcp/overview.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["metrics"]).to include("approved_oauth_clients" => 0)
      checklist_labels = response.parsed_body["setup_checklist"].pluck("label")
      expect(checklist_labels).to contain_exactly(
        I18n.t("mcp.admin.site_enabled"),
        I18n.t("mcp.admin.primitives_enabled"),
        I18n.t("mcp.admin.client_registered"),
      )
    end
  end

  describe "#primitives" do
    it "returns the registered OAuth scopes as selectable configuration options" do
      get "/admin/mcp/capabilities.json"

      expect(response.status).to eq(200)
      scopes = response.parsed_body["available_scopes"]
      expect(scopes).to eq(scopes.uniq.sort)
      expect(scopes).to include("mcp:profile:read", "mcp:content:read", "mcp:content:write")
      expect(response.parsed_body["primitives"]).to be_present
    end
  end

  describe "#access" do
    it "returns one persisted access rule per group with Admins pre-registered" do
      group = Fabricate(:group, name: "writers")
      McpGroupScope.create!(group: group, scope: "mcp:profile:read")
      McpGroupScope.create!(group: group, scope: "mcp:content:read")

      get "/admin/mcp/access.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["available_scopes"]).to include(
        "mcp:profile:read",
        "mcp:content:read",
      )
      expect(response.parsed_body["primitives"]).to be_present
      expect(response.parsed_body["access_rules"]).to contain_exactly(
        {
          "group_id" => Group::AUTO_GROUPS[:admins],
          "group_name" => "admins",
          "scopes" => DiscourseMcp.registry.scopes,
          "pre_registered" => true,
          "deletable" => false,
        },
        {
          "group_id" => group.id,
          "group_name" => group.name,
          "scopes" => %w[mcp:content:read mcp:profile:read],
          "pre_registered" => false,
          "deletable" => true,
        },
      )
      expect(McpGroupScope.where(group_id: Group::AUTO_GROUPS[:admins])).to be_present
    end
  end

  describe "#update_access" do
    it "replaces the scopes for one group" do
      group = Fabricate(:group)
      McpGroupScope.create!(group: group, scope: "mcp:profile:read")

      put "/admin/mcp/access/#{group.id}.json",
          params: {
            scopes: %w[mcp:content:read mcp:content:write],
          }

      expect(response.status).to eq(200)
      expect(McpGroupScope.where(group: group).pluck(:scope)).to contain_exactly(
        "mcp:content:read",
        "mcp:content:write",
        "mcp:profile:read",
      )
    end

    it "rejects unknown scopes" do
      group = Fabricate(:group)

      put "/admin/mcp/access/#{group.id}.json", params: { scopes: ["mcp:unknown"] }

      expect(response.status).to eq(400)
      expect(McpGroupScope.where(group: group)).to be_empty
    end

    it "allows the pre-registered Admins scopes to be changed" do
      McpGroupScope.ensure_admins!

      put "/admin/mcp/access/#{Group::AUTO_GROUPS[:admins]}.json",
          params: {
            scopes: ["mcp:profile:read"],
          }

      expect(response.status).to eq(200)
      expect(McpGroupScope.where(group_id: Group::AUTO_GROUPS[:admins]).pluck(:scope)).to eq(
        ["mcp:profile:read"],
      )
    end

    it "does not allow moderators to change group access" do
      group = Fabricate(:group)
      sign_in(moderator)

      put "/admin/mcp/access/#{group.id}.json", params: { scopes: ["mcp:profile:read"] }

      expect(response.status).to eq(404)
      expect(McpGroupScope.where(group: group)).to be_empty
    end
  end

  describe "#destroy_access" do
    it "removes the scopes for one group" do
      group = Fabricate(:group)
      McpGroupScope.create!(group: group, scope: "mcp:profile:read")

      delete "/admin/mcp/access/#{group.id}.json"

      expect(response.status).to eq(204)
      expect(McpGroupScope.where(group: group)).to be_empty
    end

    it "does not remove the pre-registered Admins rule" do
      McpGroupScope.ensure_admins!

      delete "/admin/mcp/access/#{Group::AUTO_GROUPS[:admins]}.json"

      expect(response.status).to eq(400)
      expect(McpGroupScope.where(group_id: Group::AUTO_GROUPS[:admins])).to be_present
    end
  end

  describe "#emergency_block" do
    it "immediately blocks and unblocks a registered primitive" do
      params = { primitive_id: "tool:discourse_search", blocked: true }

      put "/admin/mcp/capabilities/emergency-block.json", params: params

      expect(response.status).to eq(200)
      policy = McpPrimitive.find_by!(kind: "tool", identifier: "discourse_search")
      expect(policy).to be_emergency_blocked

      put "/admin/mcp/capabilities/emergency-block.json", params: params.merge(blocked: false)

      expect(response.status).to eq(200)
      expect(policy.reload).not_to be_emergency_blocked
    end

    it "requires fresh consent only when unblocking expands privileged access" do
      SiteSetting.mcp_server_enabled = true
      McpGroupScope.ensure_admins!
      client =
        McpOauthClient.create!(
          client_id: "emergency-block-spec-client",
          name: "Emergency block spec client",
          registration_type: "pre_registered",
          trust_state: "approved",
          redirect_uris: ["http://127.0.0.1/callback"],
        )
      authorization =
        DiscourseMcp::OAuth::AuthorizationGrant.create!(
          user: admin,
          client: client,
          redirect_uri: client.redirect_uris.first,
          requested_scopes: %w[mcp:content:write mcp:profile:read],
        )
      McpOauthAccessToken.issue!(authorization: authorization)
      token = authorization.access_tokens.last
      McpPrimitive.create!(kind: "tool", identifier: "discourse_post_set_deleted", enabled: true)
      params = { primitive_id: "tool:discourse_post_set_deleted", blocked: true }

      put "/admin/mcp/capabilities/emergency-block.json", params: params

      expect(response.status).to eq(200)
      expect(authorization.reload.status).to eq("active")
      expect(token.reload.revoked_at).to be_blank

      put "/admin/mcp/capabilities/emergency-block.json", params: params.merge(blocked: false)

      expect(response.status).to eq(200)
      expect(authorization.reload.status).to eq("consent_required")
      expect(token.reload.revoked_at).to be_present
    end
  end

  describe "#update_primitives" do
    it "requires fresh consent and revokes tokens when a privileged primitive is exposed" do
      SiteSetting.mcp_server_enabled = true
      McpGroupScope.ensure_admins!
      client =
        McpOauthClient.create!(
          client_id: "admin-mcp-controller-spec-client",
          name: "Admin MCP controller spec client",
          registration_type: "pre_registered",
          trust_state: "approved",
          redirect_uris: ["http://127.0.0.1/callback"],
        )
      authorization =
        DiscourseMcp::OAuth::AuthorizationGrant.create!(
          user: admin,
          client: client,
          redirect_uri: client.redirect_uris.first,
          requested_scopes: %w[mcp:profile:read mcp:content:write],
        )
      McpOauthAccessToken.issue!(authorization: authorization)
      McpOauthRefreshToken.issue!(authorization: authorization)
      profile_client =
        McpOauthClient.create!(
          client_id: "profile-only-spec-client",
          name: "Profile-only spec client",
          registration_type: "pre_registered",
          trust_state: "approved",
          redirect_uris: ["http://127.0.0.1/profile-callback"],
        )
      profile_authorization =
        DiscourseMcp::OAuth::AuthorizationGrant.create!(
          user: admin,
          client: profile_client,
          redirect_uri: profile_client.redirect_uris.first,
          requested_scopes: ["mcp:profile:read"],
        )
      McpOauthAccessToken.issue!(authorization: profile_authorization)

      put "/admin/mcp/capabilities.json",
          params: {
            primitive_ids: ["tool:discourse_post_set_deleted"],
          }

      expect(response.status).to eq(200)
      primitive = McpPrimitive.find_by!(kind: "tool", identifier: "discourse_post_set_deleted")
      expect(primitive).to be_enabled
      expect(primitive.consent_required_at).to be_present
      expect(authorization.reload.status).to eq("consent_required")
      expect(authorization.access_tokens.where(revoked_at: nil)).to be_empty
      expect(authorization.refresh_tokens.where(revoked_at: nil)).to be_empty
      expect(profile_authorization.reload.status).to eq("active")
      expect(profile_authorization.access_tokens.where(revoked_at: nil)).to be_present
    end

    it "does not require fresh consent when a read-only primitive is exposed" do
      SiteSetting.mcp_server_enabled = true
      McpGroupScope.ensure_admins!
      client =
        McpOauthClient.create!(
          client_id: "read-only-primitive-spec-client",
          name: "Read-only primitive spec client",
          registration_type: "pre_registered",
          trust_state: "approved",
          redirect_uris: ["http://127.0.0.1/callback"],
        )
      authorization =
        DiscourseMcp::OAuth::AuthorizationGrant.create!(
          user: admin,
          client: client,
          redirect_uri: client.redirect_uris.first,
          requested_scopes: ["mcp:profile:read"],
        )

      put "/admin/mcp/capabilities.json",
          params: {
            primitive_ids: ["tool:discourse_current_user_get"],
          }

      expect(response.status).to eq(200)
      primitive = McpPrimitive.find_by!(kind: "tool", identifier: "discourse_current_user_get")
      expect(primitive.consent_required_at).to be_blank
      expect(authorization.reload.status).to eq("active")
    end
  end
end
