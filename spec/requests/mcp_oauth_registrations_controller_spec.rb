# frozen_string_literal: true

describe McpOauthRegistrationsController do
  fab!(:admin)

  let(:metadata) do
    { client_name: "Example agent", redirect_uris: ["https://agent.example.com/callback"] }
  end

  before { SiteSetting.mcp_server_enabled = true }

  def register(body = metadata, content_type: "application/json", remote_addr: nil)
    headers = { "CONTENT_TYPE" => content_type }
    headers["REMOTE_ADDR"] = remote_addr if remote_addr
    post "/oauth2/mcp/register", params: body.is_a?(String) ? body : body.to_json, headers:
  end

  it "registers a public client and describes it" do
    expect { register }.to change { McpOauthClient.count }.by(1)

    expect(response.status).to eq(201)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(response.parsed_body).to include(
      "client_name" => "Example agent",
      "redirect_uris" => ["https://agent.example.com/callback"],
      "token_endpoint_auth_method" => "none",
      "grant_types" => %w[authorization_code refresh_token],
      "response_types" => ["code"],
    )
    expect(response.parsed_body).not_to have_key("client_secret")
    expect(
      McpOauthClient.find_by!(client_id: response.parsed_body["client_id"]),
    ).to have_attributes(registration_type: "dcr", trust_state: "approved", name: "Example agent")
  end

  it "registers an app that asks for a client secret as a public client" do
    %w[client_secret_basic client_secret_post].each do |method|
      register(metadata.merge(token_endpoint_auth_method: method))

      expect(response.status).to eq(201)
      expect(response.parsed_body["token_endpoint_auth_method"]).to eq("none")
    end
  end

  it "accepts metadata it doesn't use" do
    register(
      metadata.merge(
        scope: "offline_access mcp:profile:read",
        logo_uri: "https://agent.example.com/logo.png",
        grant_types: %w[
          authorization_code
          refresh_token
          urn:ietf:params:oauth:grant-type:jwt-bearer
        ],
        unknown_extension: {
          nested: true,
        },
      ),
    )

    expect(response.status).to eq(201)
    client = McpOauthClient.find_by!(client_id: response.parsed_body["client_id"])
    expect(client.metadata).to include("scope" => "offline_access mcp:profile:read")
    expect(client.metadata).not_to have_key("unknown_extension")
  end

  it "names an unnamed app after the host it redirects to" do
    register(metadata.except(:client_name))

    expect(response.parsed_body["client_name"]).to eq("agent.example.com")
  end

  it "accepts explicit JSON null for optional metadata fields" do
    register(
      metadata.merge(
        client_name: nil,
        token_endpoint_auth_method: nil,
        grant_types: nil,
        response_types: nil,
        client_secret: nil,
      ),
    )

    expect(response.status).to eq(201)
    expect(response.parsed_body).to include(
      "client_name" => "agent.example.com",
      "token_endpoint_auth_method" => "none",
      "grant_types" => %w[authorization_code refresh_token],
      "response_types" => ["code"],
    )
  end

  it "accepts loopback redirect URIs for apps on the user's computer" do
    register(metadata.merge(redirect_uris: ["http://127.0.0.1:33418/callback"]))

    expect(response.status).to eq(201)
  end

  it "rejects clients that would authenticate with a key or a secret of their own" do
    [
      metadata.merge(token_endpoint_auth_method: "private_key_jwt"),
      metadata.merge(client_secret: "chosen-by-the-app"),
    ].each do |body|
      expect { register(body) }.not_to change { McpOauthClient.count }
      expect(response.status).to eq(400)
      expect(response.parsed_body["error"]).to eq("invalid_client_metadata")
    end
  end

  it "rejects redirect URIs it can't send a code to safely" do
    long_uri =
      "https://agent.example.com/#{"a" * DiscourseMcp::OAuth::ClientRegistration::MAX_VALUE_LENGTH}"
    [
      nil,
      [],
      ["http://agent.example.com/callback"],
      ["https://agent.example.com/callback#fragment"],
      ["https://user@agent.example.com/callback"],
      ["agent.example.com/callback"],
      [long_uri],
      Array.new(21) { |index| "https://agent.example.com/#{index}" },
    ].each do |redirect_uris|
      expect { register(metadata.merge(redirect_uris:)) }.not_to change { McpOauthClient.count }
      expect(response.status).to eq(400)
      expect(response.parsed_body["error"]).to eq("invalid_redirect_uri")
    end
  end

  it "requires the authorization code flow" do
    [
      metadata.merge(grant_types: ["client_credentials"]),
      metadata.merge(response_types: ["token"]),
    ].each do |body|
      register(body)

      expect(response.status).to eq(400)
      expect(response.parsed_body["error"]).to eq("invalid_client_metadata")
    end
  end

  it "rejects requests that aren't a JSON object" do
    register("{not json")
    expect(response.status).to eq(400)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(response.parsed_body["error"]).to eq("invalid_client_metadata")

    register([metadata].to_json)
    expect(response.status).to eq(400)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(response.parsed_body["error"]).to eq("invalid_client_metadata")

    register(metadata, content_type: "application/x-www-form-urlencoded")
    expect(response.status).to eq(400)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(response.parsed_body["error"]).to eq("invalid_client_metadata")
    expect(McpOauthClient.count).to eq(0)
  end

  it "rejects payloads larger than MAX_REQUEST_BYTES" do
    oversized_valid =
      metadata.merge(client_name: "a" * McpOauthRegistrationsController::MAX_REQUEST_BYTES).to_json
    oversized_invalid = "{" * (McpOauthRegistrationsController::MAX_REQUEST_BYTES + 1)

    [oversized_valid, oversized_invalid].each do |body|
      expect { register(body) }.not_to change { McpOauthClient.count }
      expect(response.status).to eq(400)
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.parsed_body).to eq(
        "error" => "invalid_client_metadata",
        "error_description" => "The metadata is too large.",
      )
    end
  end

  it "rejects metadata values containing null bytes" do
    [
      metadata.merge(client_name: "Example\u0000agent"),
      metadata.merge(software_id: "soft\u0000ware"),
      metadata.merge(grant_types: ["authorization_code", "custom\u0000type"]),
    ].each do |body|
      expect { register(body) }.not_to change { McpOauthClient.count }
      expect(response.status).to eq(400)
      expect(response.parsed_body["error"]).to eq("invalid_client_metadata")
    end
  end

  it "registers clients when login is required" do
    SiteSetting.login_required = true

    expect { register }.to change { McpOauthClient.count }.by(1)
    expect(response.status).to eq(201)
  end

  it "isn't available when registration is turned off" do
    SiteSetting.mcp_oauth_dynamic_client_registration = false

    register
    expect(response.status).to eq(404)

    register("{not json")
    expect(response.status).to eq(404)
  end

  it "isn't available unless any domain may identify a client" do
    SiteSetting.mcp_oauth_client_id_metadata_policy = "approved_domains"

    register

    expect(response.status).to eq(404)
  end

  it "isn't available when MCP is disabled" do
    SiteSetting.mcp_server_enabled = false

    register

    expect(response.status).to eq(404)
  end

  it "limits how often one address can register" do
    RateLimiter.enable
    stub_const(described_class, "REGISTRATIONS_PER_IP_PER_HOUR", 1) do
      register
      expect(response.status).to eq(201)

      register
      expect(response.status).to eq(429)
    end
  end

  it "limits registrations across the site without counting invalid requests" do
    RateLimiter.enable
    stub_const(described_class, "REGISTRATIONS_PER_HOUR", 2) do
      register("{not json", remote_addr: "192.0.2.1")
      expect(response.status).to eq(400)

      register(
        metadata.merge(redirect_uris: ["http://agent.example.com/callback"]),
        remote_addr: "192.0.2.2",
      )
      expect(response.status).to eq(400)

      register(metadata, remote_addr: "192.0.2.3")
      expect(response.status).to eq(201)

      register(metadata, remote_addr: "192.0.2.4")
      expect(response.status).to eq(201)

      register(metadata, remote_addr: "192.0.2.5")
      expect(response.status).to eq(429)
    end
  end

  it "lets a registered app connect, call a tool and refresh its token" do
    McpPrimitive.create!(kind: "tool", identifier: "discourse_current_user_get", enabled: true)
    register
    client_id = response.parsed_body["client_id"]
    redirect_uri = metadata[:redirect_uris].first
    verifier = "v" * 43
    authorization = {
      client_id:,
      redirect_uri:,
      response_type: "code",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256",
      resource: DiscourseMcp.resource_url,
      scope: "mcp:profile:read",
      state: "state",
    }

    sign_in(admin)
    get "/oauth2/mcp/authorize", params: authorization
    expect(response.status).to eq(200)

    post "/oauth2/mcp/authorize", params: authorization.merge(decision: "approve")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    expect(code).to be_present

    post "/oauth2/mcp/token",
         params: {
           grant_type: "authorization_code",
           code:,
           client_id:,
           redirect_uri:,
           code_verifier: verifier,
           resource: DiscourseMcp.resource_url,
         }
    expect(response.status).to eq(200)
    tokens = response.parsed_body

    post "/mcp",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "discourse_current_user_get",
             arguments: {
             },
           },
         }.to_json,
         headers: {
           "HTTP_AUTHORIZATION" => "Bearer #{tokens["access_token"]}",
           "CONTENT_TYPE" => "application/json",
           "HTTP_ACCEPT" => "application/json, text/event-stream",
           "HTTP_MCP_PROTOCOL_VERSION" => DiscourseMcp::LEGACY_PROTOCOL_VERSION,
         }
    expect(response.status).to eq(200)
    expect(response.body).to include(admin.username)

    post "/oauth2/mcp/token",
         params: {
           grant_type: "refresh_token",
           refresh_token: tokens["refresh_token"],
           client_id:,
           resource: DiscourseMcp.resource_url,
         }
    expect(response.status).to eq(200)
    expect(response.parsed_body["access_token"]).to be_present
  end
end
