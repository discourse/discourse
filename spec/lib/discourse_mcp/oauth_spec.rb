# frozen_string_literal: true

describe DiscourseMcp::OAuth do
  fab!(:user)
  fab!(:group)
  fab!(:other_group, :group)

  let(:granted_scopes) { %w[mcp:profile:read mcp:content:read] }

  let(:client) do
    McpOauthClient.create!(
      client_id: "oauth-spec-client",
      name: "OAuth spec client",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end
  let(:authorization) do
    described_class::AuthorizationGrant.create!(
      user: user,
      client: client,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: granted_scopes,
    )
  end
  let(:verifier) { "v" * 43 }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

  before do
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    other_group.add(user)
    McpGroupScope.create!(group: group, scope: "mcp:profile:read")
    McpGroupScope.create!(group: other_group, scope: "mcp:content:read")
  end

  it "authorizes scopes combined from all of the user's groups" do
    expect(authorization.scopes).to contain_exactly(*granted_scopes)
  end

  it "requires the initial scope when granting authorization" do
    expect do
      described_class::AuthorizationGrant.create!(
        user: user,
        client: client,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: %w[mcp:content:read],
      )
    end.to raise_error(Discourse::InvalidAccess)
  end

  it "rejects a requested scope that none of the user's groups provide" do
    expect do
      described_class::AuthorizationGrant.create!(
        user: user,
        client: client,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: %w[mcp:profile:read mcp:content:write],
      )
    end.to raise_error(Discourse::InvalidAccess)
  end

  it "does not add newly eligible scopes during refresh" do
    subset_authorization =
      described_class::AuthorizationGrant.create!(
        user: user,
        client: client,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: %w[mcp:profile:read],
      )
    refresh_token, = McpOauthRefreshToken.issue!(authorization: subset_authorization)
    McpGroupScope.create!(group: group, scope: "mcp:content:write")

    result =
      described_class::TokenIssuer.refresh!(
        refresh_token: refresh_token,
        client_id: client.client_id,
        resource: DiscourseMcp.resource_url,
      )

    expect(result[:scope]).to eq("mcp:profile:read")
  end

  it "does not allow refresh to remove the initial scope" do
    refresh_token, = McpOauthRefreshToken.issue!(authorization: authorization)

    expect do
      described_class::TokenIssuer.refresh!(
        refresh_token: refresh_token,
        client_id: client.client_id,
        resource: DiscourseMcp.resource_url,
        requested_scopes: %w[mcp:content:read],
      )
    end.to raise_error(Discourse::InvalidAccess)
  end

  it "keeps a token valid while another group still provides every token scope" do
    McpGroupScope.create!(group: group, scope: "mcp:content:read")
    access_token = McpOauthAccessToken.issue!(authorization: authorization)
    request = Struct.new(:authorization).new("Bearer #{access_token}")

    McpGroupScope.where(group: other_group, scope: "mcp:content:read").delete_all

    expect(DiscourseMcp::Authenticator.new(request).authenticate!).to be_a(
      DiscourseMcp::RequestContext,
    )

    McpGroupScope.where(group: group, scope: "mcp:content:read").delete_all

    expect { DiscourseMcp::Authenticator.new(request).authenticate! }.to raise_error(
      DiscourseMcp::AuthenticationError,
    )
  end

  it "keeps a subset token valid when another authorized scope is no longer eligible" do
    access_token =
      McpOauthAccessToken.issue!(authorization: authorization, scopes: %w[mcp:profile:read])
    request = Struct.new(:authorization).new("Bearer #{access_token}")

    McpGroupScope.where(group: other_group, scope: "mcp:content:read").delete_all

    expect(DiscourseMcp::AuthorizationStatus.for([authorization])[authorization.id]).to eq(
      "access_removed",
    )
    expect(DiscourseMcp::Authenticator.new(request).authenticate!).to be_a(
      DiscourseMcp::RequestContext,
    )
  end

  it "exchanges an S256 authorization code exactly once" do
    code =
      McpOauthAuthorizationCode.issue!(
        authorization: authorization,
        redirect_uri: client.redirect_uris.first,
        resource: DiscourseMcp.resource_url,
        code_challenge: challenge,
      )

    result =
      described_class::TokenIssuer.exchange_code!(
        code: code,
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_verifier: verifier,
        resource: DiscourseMcp.resource_url,
      )

    expect(result.slice(:token_type, :scope)).to eq(
      token_type: "Bearer",
      scope: granted_scopes.join(" "),
    )
    expect(result.values_at(:access_token, :refresh_token)).to all(be_present)
    expect do
      described_class::TokenIssuer.exchange_code!(
        code: code,
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_verifier: verifier,
        resource: DiscourseMcp.resource_url,
      )
    end.to raise_error(Discourse::InvalidAccess)
  end

  it "rotates refresh tokens and revokes the family when a consumed token is replayed" do
    refresh_token, record = McpOauthRefreshToken.issue!(authorization: authorization)

    result =
      described_class::TokenIssuer.refresh!(
        refresh_token: refresh_token,
        client_id: client.client_id,
        resource: DiscourseMcp.resource_url,
      )

    expect(result[:refresh_token]).to be_present
    expect(record.reload.consumed_at).to be_present
    expect do
      described_class::TokenIssuer.refresh!(
        refresh_token: refresh_token,
        client_id: client.client_id,
        resource: DiscourseMcp.resource_url,
      )
    end.to raise_error(Discourse::InvalidAccess)
    expect(
      McpOauthRefreshToken.where(family_id: record.family_id).where(revoked_at: nil),
    ).to be_empty
  end

  it "invalidates existing credentials when consent is replaced" do
    access_token = McpOauthAccessToken.issue!(authorization: authorization)

    described_class::AuthorizationGrant.create!(
      user: user,
      client: client,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: %w[mcp:profile:read],
    )

    request = Struct.new(:authorization).new("Bearer #{access_token}")
    expect { DiscourseMcp::Authenticator.new(request).authenticate! }.to raise_error(
      DiscourseMcp::AuthenticationError,
    )
    expect(
      McpOauthAccessToken.find_by(token_hash: McpOauthAccessToken.digest(access_token)).revoked_at,
    ).to be_present
  end

  it "rejects credentials consented before the latest primitive consent change" do
    access_token = McpOauthAccessToken.issue!(authorization: authorization)
    McpPrimitive.create!(
      kind: "tool",
      identifier: "discourse.post.get",
      enabled: true,
      consent_required_at: 1.second.from_now,
    )
    request = Struct.new(:authorization).new("Bearer #{access_token}")

    expect { DiscourseMcp::Authenticator.new(request).authenticate! }.to raise_error(
      DiscourseMcp::AuthenticationError,
    )
  end

  it "rejects refresh scopes removed from the user's current group access" do
    refresh_token, = McpOauthRefreshToken.issue!(authorization: authorization)
    McpGroupScope.where(group: other_group, scope: "mcp:content:read").delete_all

    expect do
      described_class::TokenIssuer.refresh!(
        refresh_token: refresh_token,
        client_id: client.client_id,
        resource: DiscourseMcp.resource_url,
      )
    end.to raise_error(Discourse::InvalidAccess)
  end

  it "rejects authorization while the MCP server is disabled" do
    SiteSetting.mcp_server_enabled = false

    expect do
      described_class::AuthorizationGrant.create!(
        user: user,
        client: client,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: granted_scopes,
      )
    end.to raise_error(Discourse::InvalidAccess)
  end
end
