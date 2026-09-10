# frozen_string_literal: true

describe McpOauthTokensController do
  fab!(:user)
  fab!(:group)

  let(:client) do
    McpOauthClient.create!(
      client_id: "token-controller-spec-client",
      name: "Token controller spec client",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end
  let(:authorization) do
    DiscourseMcp::OAuth::AuthorizationGrant.create!(
      user:,
      client:,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: ["mcp:profile:read"],
    )
  end
  let(:verifier) { "v" * 43 }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

  before do
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    McpGroupScope.create!(group:, scope: "mcp:profile:read")
  end

  describe "#create" do
    it "returns invalid_grant when the authorization no longer exists" do
      code =
        McpOauthAuthorizationCode.issue!(
          authorization:,
          redirect_uri: client.redirect_uris.first,
          resource: DiscourseMcp.resource_url,
          code_challenge: challenge,
        )
      authorization.delete

      post "/oauth2/mcp/token",
           params: {
             grant_type: "authorization_code",
             code:,
             client_id: client.client_id,
             redirect_uri: client.redirect_uris.first,
             code_verifier: verifier,
             resource: DiscourseMcp.resource_url,
           }

      expect(response.status).to eq(400)
      expect(response.parsed_body).to eq("error" => "invalid_grant")
    end
  end
end
