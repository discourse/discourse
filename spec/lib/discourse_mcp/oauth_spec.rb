# frozen_string_literal: true

RSpec.describe DiscourseMcp::OAuth do
  fab!(:admin)

  let(:profile) do
    McpServerProfile.create!(
      name: "OAuth profile",
      slug: "oauth",
      enabled: true,
      allowed_group_ids: admin.group_ids,
      allowed_scopes: %w[mcp:profile:discover mcp:content:read],
    )
  end
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
      user: admin,
      client: client,
      profile: profile,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: profile.allowed_scopes,
    )
  end
  let(:verifier) { "v" * 43 }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

  before { SiteSetting.mcp_server_enabled = true }

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
      scope: profile.allowed_scopes.join(" "),
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
      user: admin,
      client: client,
      profile: profile,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: %w[mcp:profile:discover],
    )

    request = Struct.new(:authorization).new("Bearer #{access_token}")
    expect { DiscourseMcp::Authenticator.new(request).authenticate! }.to raise_error(
      DiscourseMcp::AuthenticationError,
    )
    expect(
      McpOauthAccessToken.find_by(token_hash: McpOauthAccessToken.digest(access_token)).revoked_at,
    ).to be_present
  end

  it "rejects refresh scopes removed from the current profile" do
    refresh_token, = McpOauthRefreshToken.issue!(authorization: authorization)
    profile.update!(allowed_scopes: %w[mcp:profile:discover])

    expect do
      described_class::TokenIssuer.refresh!(
        refresh_token: refresh_token,
        client_id: client.client_id,
        resource: DiscourseMcp.resource_url,
      )
    end.to raise_error(Discourse::InvalidAccess)
  end
end
