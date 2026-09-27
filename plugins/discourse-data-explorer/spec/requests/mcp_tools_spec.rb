# frozen_string_literal: true

describe "Data Explorer MCP tools" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:other_group, :group)
  fab!(:query) { Fabricate(:query, sql: "SELECT 1::integer AS value") }

  before do
    SiteSetting.data_explorer_enabled = true
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    Fabricate(:query_group, query:, group:)
    McpPrimitive.find_or_create_by!(kind: "tool", identifier: "discourse_run_query") do |primitive|
      primitive.enabled = true
    end
  end

  def authorize(*extra_scopes)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *extra_scopes]
    scopes.each { |scope| McpGroupScope.create!(group:, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Data Explorer test client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    authorization =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user:,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: scopes,
      )
    @token = McpOauthAccessToken.issue!(authorization:)
  end

  def call_run_query
    post "/mcp",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "discourse_run_query",
             arguments: {
               id: query.id,
             },
           },
         }.to_json,
         headers: {
           "HTTP_AUTHORIZATION" => "Bearer #{@token}",
           "CONTENT_TYPE" => "application/json",
           "HTTP_ACCEPT" => "application/json, text/event-stream",
           "HTTP_MCP_PROTOCOL_VERSION" => DiscourseMcp::LEGACY_PROTOCOL_VERSION,
         }
  end

  it "requires the Data Explorer read scope before running a query" do
    authorize

    call_run_query

    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      'scope="mcp:data-explorer:read"',
    )
  end

  it "runs an assigned query when the token has the Data Explorer read scope" do
    authorize(DiscourseDataExplorer::McpTools::READ_SCOPE)

    call_run_query

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent")).to include(
      "columns" => ["value"],
      "rows" => [[1]],
    )
  end

  it "does not run a query when the token has scope but the user lacks query access" do
    query.query_groups.delete_all
    Fabricate(:query_group, query:, group: other_group)
    authorize(DiscourseDataExplorer::McpTools::READ_SCOPE)

    call_run_query

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.parsed_body.dig("result", "content")).to eq(
      [{ "type" => "text", "text" => I18n.t("discourse_data_explorer.mcp.query_not_found") }],
    )
  end

  it "applies the Data Explorer API query rate limit" do
    SiteSetting.mcp_global_rate_limit_per_minute = 100
    global_setting :max_data_explorer_api_reqs_per_10_seconds, 1
    global_setting :max_data_explorer_api_req_mode, "block"
    RateLimiter.enable
    authorize(DiscourseDataExplorer::McpTools::READ_SCOPE)

    freeze_time
    call_run_query
    expect(response.status).to eq(200)

    call_run_query
    expect(response.status).to eq(429)
    expect(response.headers["Retry-After"]).to eq("10")
    expect(response.parsed_body).to eq(
      "jsonrpc" => "2.0",
      "id" => nil,
      "error" => {
        "code" => -32_000,
        "message" => "Rate limit exceeded",
      },
    )
  end
end
