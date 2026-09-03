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

  it "rejects an unapproved metadata domain before registering the client" do
    client_id = "https://unapproved.example.com/oauth/client.json"
    SiteSetting.mcp_oauth_client_trust_policy = "approved_domains"
    SiteSetting.mcp_oauth_approved_domains = "approved.example.com"
    allow(described_class::ClientResolver).to receive(:fetch_metadata).and_return(
      {
        "client_id" => client_id,
        "client_name" => "Unapproved client",
        "redirect_uris" => ["https://unapproved.example.com/callback"],
      },
    )

    expect { described_class::ClientResolver.resolve!(client_id, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
    expect(McpOauthClient.find_by(client_id:)).to eq(nil)
  end

  it "rejects a cached metadata client that the current trust policy does not allow" do
    SiteSetting.mcp_oauth_client_trust_policy = "pre_registered"
    client_id = "https://client.example.com/oauth/client.json"
    McpOauthClient.create!(
      client_id:,
      name: "Cached metadata client",
      registration_type: "cimd",
      trust_state: "approved",
      metadata_uri: client_id,
      metadata_expires_at: 1.hour.from_now,
      redirect_uris: ["https://client.example.com/callback"],
    )

    expect { described_class::ClientResolver.resolve!(client_id, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
  end

  it "rejects client ID URLs containing dot path segments" do
    SiteSetting.mcp_oauth_client_trust_policy = "any_cimd"
    client_id = "https://client.example.com/oauth/../client.json"
    allow(described_class::ClientResolver).to receive(:fetch_metadata).and_return(
      {
        "client_id" => client_id,
        "client_name" => "Invalid metadata client",
        "redirect_uris" => ["https://client.example.com/callback"],
      },
    )

    expect { described_class::ClientResolver.resolve!(client_id, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
    expect(McpOauthClient.find_by(client_id:)).to eq(nil)
  end

  it "rejects metadata that requires unsupported client authentication" do
    SiteSetting.mcp_oauth_client_trust_policy = "any_cimd"
    client_id = "https://client.example.com/oauth/client.json"
    allow(described_class::ClientResolver).to receive(:fetch_metadata).and_return(
      {
        "client_id" => client_id,
        "client_name" => "Confidential metadata client",
        "redirect_uris" => ["https://client.example.com/callback"],
        "token_endpoint_auth_method" => "private_key_jwt",
      },
    )

    expect { described_class::ClientResolver.resolve!(client_id, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
    expect(McpOauthClient.find_by(client_id:)).to eq(nil)
  end

  it "handles metadata responses without a body chunk" do
    SiteSetting.mcp_oauth_client_trust_policy = "any_cimd"
    client_id = "https://client.example.com/oauth/client.json"
    response = instance_double(Net::HTTPResponse, code: "302")
    allow(response).to receive(:[]).with("Content-Type").and_return("text/html")
    destination = instance_double(FinalDestination)
    allow(FinalDestination).to receive(:new).and_return(destination)
    allow(destination).to receive(:get).and_yield(response, nil, nil)

    expect { described_class::ClientResolver.resolve!(client_id, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
  end

  it "rate limits metadata lookups across hostname case variants" do
    SiteSetting.mcp_oauth_client_trust_policy = "any_cimd"
    RateLimiter.enable
    users = 4.times.map { Fabricate(:user) }
    lowercase_host = "client-#{SecureRandom.hex}.example.com"
    uppercase_host = lowercase_host.upcase
    allow(described_class::ClientResolver).to receive(:fetch_metadata) do |uri|
      {
        "client_id" => uri.to_s,
        "client_name" => "Metadata client",
        "redirect_uris" => ["https://client.example.com/callback"],
      }
    end

    30.times do |index|
      host = index.even? ? lowercase_host : uppercase_host
      described_class::ClientResolver.resolve!(
        "https://#{host}/oauth/client-#{index}.json",
        user: users[index % users.length],
      )
    end

    expect do
      described_class::ClientResolver.resolve!(
        "https://#{uppercase_host}/oauth/client-30.json",
        user: users.last,
      )
    end.to raise_error(RateLimiter::LimitExceeded)
  end

  it "rejects existing credentials when the current policy no longer allows the client" do
    SiteSetting.mcp_oauth_client_trust_policy = "any_cimd"
    client_id = "https://client.example.com/oauth/client.json"
    metadata_client =
      McpOauthClient.create!(
        client_id:,
        name: "Metadata client",
        registration_type: "cimd",
        trust_state: "approved",
        metadata_uri: client_id,
        redirect_uris: ["https://client.example.com/callback"],
      )
    metadata_authorization =
      described_class::AuthorizationGrant.create!(
        user:,
        client: metadata_client,
        redirect_uri: metadata_client.redirect_uris.first,
        requested_scopes: granted_scopes,
      )
    access_token = McpOauthAccessToken.issue!(authorization: metadata_authorization)
    refresh_token, = McpOauthRefreshToken.issue!(authorization: metadata_authorization)
    request = Struct.new(:authorization).new("Bearer #{access_token}")
    SiteSetting.stubs(:mcp_oauth_client_trust_policy).returns("pre_registered")

    expect { DiscourseMcp::Authenticator.new(request).authenticate! }.to raise_error(
      DiscourseMcp::AuthenticationError,
    )
    expect do
      described_class::TokenIssuer.refresh!(
        refresh_token:,
        client_id:,
        resource: DiscourseMcp.resource_url,
      )
    end.to raise_error(Discourse::InvalidAccess)
  end

  it "revokes metadata client grants when an approved domain is removed" do
    SiteSetting.mcp_oauth_client_trust_policy = "approved_domains"
    SiteSetting.mcp_oauth_approved_domains = "client.example.com"
    client_id = "https://client.example.com/oauth/client.json"
    metadata_client =
      McpOauthClient.create!(
        client_id:,
        name: "Metadata client",
        registration_type: "cimd",
        trust_state: "approved",
        metadata_uri: client_id,
        redirect_uris: ["https://client.example.com/callback"],
      )
    metadata_authorization =
      described_class::AuthorizationGrant.create!(
        user:,
        client: metadata_client,
        redirect_uri: metadata_client.redirect_uris.first,
        requested_scopes: granted_scopes,
      )
    access_token = McpOauthAccessToken.issue!(authorization: metadata_authorization)
    refresh_token, refresh_record =
      McpOauthRefreshToken.issue!(authorization: metadata_authorization)

    SiteSetting.mcp_oauth_approved_domains = "other.example.com"

    expect(metadata_client.reload.trust_state).to eq("pending")
    expect(metadata_authorization.reload.status).to eq("consent_required")
    expect(
      McpOauthAccessToken.find_by(token_hash: McpOauthAccessToken.digest(access_token)).revoked_at,
    ).to be_present
    expect(refresh_record.reload.revoked_at).to be_present
    expect do
      described_class::TokenIssuer.refresh!(
        refresh_token:,
        client_id:,
        resource: DiscourseMcp.resource_url,
      )
    end.to raise_error(Discourse::InvalidAccess)
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
      identifier: "discourse_post_get",
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
