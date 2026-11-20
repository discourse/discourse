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
    context "when login is required" do
      before { SiteSetting.login_required = true }

      it "exchanges an authorization code without a browser session" do
        code =
          McpOauthAuthorizationCode.issue!(
            authorization:,
            redirect_uri: client.redirect_uris.first,
            resource: DiscourseMcp.resource_url,
            code_challenge: challenge,
          )

        post "/oauth2/mcp/token",
             params: {
               grant_type: "authorization_code",
               code:,
               client_id: client.client_id,
               redirect_uri: client.redirect_uris.first,
               code_verifier: verifier,
               resource: DiscourseMcp.resource_url,
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to include(
          "access_token" => be_present,
          "refresh_token" => be_present,
          "token_type" => "Bearer",
          "scope" => "mcp:profile:read",
        )
        expect(response.headers["Cache-Control"]).to include("no-store")
      end

      it "refreshes tokens without a browser session" do
        refresh_token, = McpOauthRefreshToken.issue!(authorization:)

        post "/oauth2/mcp/token",
             params: {
               grant_type: "refresh_token",
               refresh_token:,
               client_id: client.client_id,
               resource: DiscourseMcp.resource_url,
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to include(
          "access_token" => be_present,
          "refresh_token" => be_present,
          "token_type" => "Bearer",
          "scope" => "mcp:profile:read",
        )
        expect(response.parsed_body["refresh_token"]).not_to eq(refresh_token)
      end

      it "rejects invalid authorization codes" do
        post "/oauth2/mcp/token",
             params: {
               grant_type: "authorization_code",
               code: "invalid",
               client_id: client.client_id,
               redirect_uri: client.redirect_uris.first,
               code_verifier: verifier,
               resource: DiscourseMcp.resource_url,
             }

        expect(response.status).to eq(400)
        expect(response.parsed_body).to eq("error" => "invalid_grant")
      end
    end

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

  describe "#revoke" do
    it "revokes tokens without a browser session when login is required" do
      SiteSetting.login_required = true
      token = McpOauthAccessToken.issue!(authorization:)
      token_record = McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(token))

      post "/oauth2/mcp/revoke", params: { token: }

      expect(response.status).to eq(200)
      expect(token_record.reload.revoked_at).to be_present
    end
  end
end
