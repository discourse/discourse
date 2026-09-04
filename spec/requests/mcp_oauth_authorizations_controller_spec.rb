# frozen_string_literal: true

describe McpOauthAuthorizationsController do
  fab!(:admin)
  fab!(:user)

  before do
    sign_in(admin)
    SiteSetting.mcp_server_enabled = true
  end

  it "labels the OAuth resource as the MCP server" do
    client =
      McpOauthClient.create!(
        client_id: "consent-page-client",
        name: "Consent page client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )

    get "/oauth2/mcp/authorize",
        params: {
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          response_type: "code",
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          resource: DiscourseMcp.resource_url,
          scope: "mcp:profile:read mcp:content:read",
        }

    expect(response.status).to eq(200)
    labels = Nokogiri.HTML5(response.body).css("dt").map(&:text)
    expect(labels).to include(I18n.t("mcp.oauth.resource"))
  end

  it "prevents the authorization page from being framed when site embedding is enabled" do
    SiteSetting.allow_embedding_site_in_an_iframe = true
    SiteSetting.content_security_policy = false
    client =
      McpOauthClient.create!(
        client_id: "framing-protection-client",
        name: "Framing protection client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )

    get "/oauth2/mcp/authorize",
        params: {
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          response_type: "code",
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          resource: DiscourseMcp.resource_url,
          scope: "mcp:profile:read",
        }

    expect(response.status).to eq(200)
    expect(response.headers["X-Frame-Options"]).to eq("DENY")
    expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors 'none'")
  end

  it "rejects an authorization request without the initial scope" do
    client =
      McpOauthClient.create!(
        client_id: "missing-initial-scope-client",
        name: "Missing initial scope client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )

    get "/oauth2/mcp/authorize",
        params: {
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          response_type: "code",
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          resource: DiscourseMcp.resource_url,
          scope: "mcp:content:read",
        }

    expect(response.status).to eq(403)
  end

  it "explains when only some requested scopes can be granted" do
    sign_in(user)
    group = Fabricate(:group)
    group.add(user)
    McpGroupScope.create!(group:, scope: "mcp:profile:read")
    client =
      McpOauthClient.create!(
        client_id: "partial-consent-client",
        name: "Partial consent client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )

    get "/oauth2/mcp/authorize",
        params: {
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          response_type: "code",
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          resource: DiscourseMcp.resource_url,
          scope: "mcp:profile:read mcp:content:read mcp:content:write",
        }

    expect(response.status).to eq(200)
    document = Nokogiri.HTML5(response.body)
    expect(document.at_css(".mcp-consent__scope-summary").text.squish).to eq(
      "Partial consent client requested 3 permissions. Your account is eligible for 1.",
    )
    expect(document.css(".mcp-consent__granted-scopes code").map(&:text)).to eq(
      ["mcp:profile:read"],
    )
  end

  it "grants only the requested scopes available to the user" do
    sign_in(user)
    group = Fabricate(:group)
    group.add(user)
    McpGroupScope.create!(group:, scope: "mcp:profile:read")
    client =
      McpOauthClient.create!(
        client_id: "partial-grant-client",
        name: "Partial grant client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )

    post "/oauth2/mcp/authorize",
         params: {
           client_id: client.client_id,
           redirect_uri: client.redirect_uris.first,
           response_type: "code",
           code_challenge: "a" * 43,
           code_challenge_method: "S256",
           resource: DiscourseMcp.resource_url,
           scope: "mcp:profile:read mcp:content:read mcp:content:write",
           decision: "approve",
         }

    expect(response).to redirect_to(/\A#{Regexp.escape(client.redirect_uris.first)}\?code=/)
    expect(McpOauthAuthorization.find_by(user:, client:).scopes).to eq(["mcp:profile:read"])
  end

  it "authorizes a loopback redirect using the client's active port" do
    client =
      McpOauthClient.create!(
        client_id: "loopback-client",
        name: "Loopback client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    redirect_uri = "http://127.0.0.1:49152/callback"

    post "/oauth2/mcp/authorize",
         params: {
           client_id: client.client_id,
           redirect_uri: redirect_uri,
           response_type: "code",
           code_challenge: "a" * 43,
           code_challenge_method: "S256",
           resource: DiscourseMcp.resource_url,
           scope: "mcp:profile:read",
           decision: "approve",
         }

    expect(response).to redirect_to(/\A#{Regexp.escape(redirect_uri)}\?code=/)
  end

  it "rejects users without MCP access before registering a metadata client" do
    sign_in(user)
    client_id = "https://client.example.com/oauth/client.json"
    redirect_uri = "https://client.example.com/callback"
    SiteSetting.mcp_oauth_client_id_metadata_policy = "approved_domains"
    SiteSetting.mcp_oauth_client_id_metadata_domains = "client.example.com"
    allow(DiscourseMcp::OAuth::ClientResolver).to receive(:fetch_metadata).and_return(
      {
        "client_id" => client_id,
        "client_name" => "Metadata client",
        "redirect_uris" => [redirect_uri],
      },
    )

    get "/oauth2/mcp/authorize",
        params: {
          client_id:,
          redirect_uri:,
          response_type: "code",
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          resource: DiscourseMcp.resource_url,
          scope: "mcp:profile:read",
        }

    expect(response.status).to eq(403)
    expect(McpOauthClient.find_by(client_id:)).to eq(nil)
  end

  it "rate limits metadata lookups across unique client IDs" do
    SiteSetting.mcp_oauth_client_id_metadata_policy = "any_domain"
    RateLimiter.enable
    allow(DiscourseMcp::OAuth::ClientResolver).to receive(:fetch_metadata) do |uri|
      {
        "client_id" => uri.to_s,
        "client_name" => "Metadata client",
        "redirect_uris" => ["https://client.example.com/callback"],
      }
    end

    11.times do |index|
      get "/oauth2/mcp/authorize",
          params: {
            client_id: "https://client.example.com/oauth/client-#{index}.json",
            redirect_uri: "https://client.example.com/callback",
            response_type: "code",
            code_challenge: "a" * 43,
            code_challenge_method: "S256",
            resource: DiscourseMcp.resource_url,
            scope: "mcp:profile:read",
          }
    end

    expect(response.status).to eq(429)
  end
end
