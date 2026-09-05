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

  describe "#index" do
    it "returns the effective authorization status" do
      McpGroupScope.create!(group: group, scope: "mcp:profile:read")
      client = create_client(client_id: "admin-authorizations-spec-client")
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

    it "paginates authorizations" do
      older_authorization = create_authorization(user: user, client_id: "older-client")
      newer_authorization = create_authorization(user: user, client_id: "newer-client")

      get "/admin/mcp/authorizations.json", params: { limit: 1 }

      expect(response.status).to eq(200)
      expect(response.parsed_body["authorizations"].pluck("id")).to eq([newer_authorization.id])

      get "/admin/mcp/authorizations.json",
          params: {
            limit: 1,
            cursor: response.parsed_body.dig("meta", "next_cursor"),
          }

      expect(response.parsed_body["authorizations"].pluck("id")).to eq([older_authorization.id])
    end

    it "filters authorizations before applying the page limit" do
      matching_user = Fabricate(:user, username: "matching-user")
      matching_authorization = create_authorization(user: matching_user, client_id: "older-client")
      create_authorization(user: user, client_id: "newer-client")

      get "/admin/mcp/authorizations.json", params: { limit: 1, filter: "matching" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["authorizations"].pluck("id")).to eq([matching_authorization.id])
    end
  end

  def create_authorization(user:, client_id:)
    McpOauthAuthorization.create!(
      user:,
      client: create_client(client_id:),
      resource: DiscourseMcp.resource_url,
      consented_at: Time.zone.now,
      status: "active",
    )
  end

  def create_client(client_id:)
    McpOauthClient.create!(
      client_id:,
      name: client_id,
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end
end
