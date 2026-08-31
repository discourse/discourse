# frozen_string_literal: true

describe "MCP transport" do
  fab!(:admin)

  let(:client) do
    McpOauthClient.create!(
      client_id: "request-spec-client",
      name: "Request spec client",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end
  let(:authorization) do
    DiscourseMcp::OAuth::AuthorizationGrant.create!(
      user: admin,
      client: client,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: %w[mcp:profile:read],
    )
  end
  let(:access_token) { McpOauthAccessToken.issue!(authorization: authorization) }
  let(:headers) do
    {
      "HTTP_AUTHORIZATION" => "Bearer #{access_token}",
      "CONTENT_TYPE" => "application/json",
      "HTTP_ACCEPT" => "application/json, text/event-stream",
      "HTTP_MCP_PROTOCOL_VERSION" => DiscourseMcp::PROTOCOL_VERSION,
      "HTTP_MCP_METHOD" => "tools/call",
      "HTTP_MCP_NAME" => "discourse_current_user_get",
    }
  end
  let(:classic_headers) do
    headers.slice("HTTP_AUTHORIZATION", "CONTENT_TYPE", "HTTP_ACCEPT").merge(
      "HTTP_MCP_PROTOCOL_VERSION" => "2025-11-25",
    )
  end
  let(:initialize_payload) do
    {
      jsonrpc: "2.0",
      id: 0,
      method: "initialize",
      params: {
        protocolVersion: "2025-11-25",
        capabilities: {
          roots: {
            listChanged: true,
          },
        },
        clientInfo: {
          name: "compatible-client",
          version: "1.0.0",
        },
      },
    }
  end
  let(:payload) do
    {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "discourse_current_user_get",
        arguments: {
        },
        _meta: {
          "io.modelcontextprotocol/protocolVersion" => DiscourseMcp::PROTOCOL_VERSION,
          "io.modelcontextprotocol/clientCapabilities" => {
          },
        },
      },
    }
  end

  before do
    SiteSetting.mcp_server_enabled = true
    McpPrimitive.create!(kind: "tool", identifier: "discourse_current_user_get", enabled: true)
  end

  it "challenges requests without bearer credentials" do
    post "/mcp", params: payload.to_json, headers: headers.except("HTTP_AUTHORIZATION")

    expect(response.status).to eq(401)
    expect(response.headers["WWW-Authenticate"]).to eq(
      %(Bearer resource_metadata="#{DiscourseMcp.protected_resource_metadata_url}", scope="mcp:profile:read"),
    )
    expect(response.parsed_body.dig("error", "code")).to eq(-32_001)
  end

  it "rejects an invalid bearer credential with an RFC 6750 error" do
    post "/mcp",
         params: payload.to_json,
         headers: headers.merge("HTTP_AUTHORIZATION" => "bearer invalid")

    expect(response.status).to eq(401)
    expect(response.headers["WWW-Authenticate"]).to include('error="invalid_token"')
  end

  it "returns an OAuth insufficient-scope challenge for an exposed tool" do
    McpPrimitive.create!(kind: "tool", identifier: "discourse_post_get", enabled: true)
    scoped_payload =
      payload.deep_merge(
        method: "tools/call",
        params: {
          name: "discourse_post_get",
          arguments: {
            post_id: 1,
          },
        },
      )
    scoped_headers = headers.merge("HTTP_MCP_NAME" => "discourse_post_get")

    post "/mcp", params: scoped_payload.to_json, headers: scoped_headers

    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      'scope="mcp:content:read"',
    )
  end

  it "negotiates a compatible protocol through the standard initialize request" do
    post "/mcp",
         params: initialize_payload.to_json,
         headers: classic_headers.except("HTTP_MCP_PROTOCOL_VERSION")

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "protocolVersion")).to eq(
      DiscourseMcp::LEGACY_PROTOCOL_VERSION,
    )
    expect(response.parsed_body.dig("result", "serverInfo", "name")).to eq("discourse")
    expect(response.parsed_body.dig("result", "capabilities", "tools")).to eq(
      "listChanged" => false,
    )
  end

  it "keeps legacy initialization on the classic protocol for an unsupported version" do
    unsupported_initialize_payload =
      initialize_payload.deep_merge(params: { protocolVersion: "2025-06-18" })

    post "/mcp",
         params: unsupported_initialize_payload.to_json,
         headers: classic_headers.except("HTTP_MCP_PROTOCOL_VERSION")

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "protocolVersion")).to eq(
      DiscourseMcp::LEGACY_PROTOCOL_VERSION,
    )
  end

  it "accepts compatible stateless requests without dated request metadata" do
    notification = { jsonrpc: "2.0", method: "notifications/initialized" }
    post "/mcp", params: notification.to_json, headers: classic_headers
    expect(response.status).to eq(202)
    expect(response.body).to be_blank

    list_request = { jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }
    post "/mcp", params: list_request.to_json, headers: classic_headers

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "tools")).to be_an(Array)
  end

  it "lists tools with underscore-only names" do
    list_request = { jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }

    post "/mcp", params: list_request.to_json, headers: classic_headers

    tool_names = response.parsed_body.dig("result", "tools").pluck("name")
    expect(tool_names).to include("discourse_current_user_get")
    expect(tool_names).to all(match(/\A[A-Za-z0-9_]+\z/))
  end

  it "uses the server-wide cache TTL setting for cacheable responses" do
    SiteSetting.mcp_cache_ttl_ms = 12_345
    discover_payload =
      payload.deep_merge(
        method: "server/discover",
        params: {
          _meta: {
            "io.modelcontextprotocol/protocolVersion" => DiscourseMcp::PROTOCOL_VERSION,
            "io.modelcontextprotocol/clientCapabilities" => {
            },
          },
        },
      )
    discover_headers = headers.except("HTTP_MCP_NAME").merge("HTTP_MCP_METHOD" => "server/discover")

    post "/mcp", params: discover_payload.to_json, headers: discover_headers

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "ttlMs")).to eq(12_345)
  end

  it "executes a stateless dated-protocol tool request" do
    post "/mcp", params: payload.to_json, headers: headers

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent", "username")).to eq(
      admin.username,
    )
    expect(response.parsed_body.dig("result", "resultType")).to eq("complete")
  end

  it "records at most one rate-limit audit event per client each minute" do
    SiteSetting.mcp_global_rate_limit_per_minute = 10
    RateLimiter.enable

    12.times { post "/mcp", params: payload.to_json, headers: headers }

    expect(response.status).to eq(429)
    expect(McpAuditLog.where(outcome: "rate_limited").count).to eq(1)
  end
end
