# frozen_string_literal: true

describe "MCP content policy transport", type: :request do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  it "[cr-u1] rejects blocked deferred tools synchronously without hijacking invoking or challenging" do
    SiteSetting.mcp_server_enabled = true
    registry = DiscourseMcp::Registry.new
    allow(DiscourseMcp).to receive(:registry).and_return(registry)
    invoked = []
    registry.register_tool(
      "oracle_deferred",
      title: "Deferred oracle",
      description: "A blocked deferred implementation must never run",
      implementation: ->(**) do
        invoked << true
        { structuredContent: { invoked: true } }
      end,
      required_scopes: [DiscourseMcp::INITIAL_SCOPE],
      content: :unbounded,
      defer: true,
    )
    McpPrimitive.create!(kind: "tool", identifier: "oracle_deferred", enabled: true)
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Deferred content policy oracle",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    authorization =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: admin,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: [DiscourseMcp::INITIAL_SCOPE],
      )
    token = McpOauthAccessToken.issue!(authorization:)
    McpContentRule.create!(rule_kind: "private_messages", config: {})
    io = StringIO.new

    Scheduler::Defer.capture_later do
      post "/mcp",
           params: {
             jsonrpc: "2.0",
             id: 1,
             method: "tools/call",
             params: {
               name: "oracle_deferred",
               arguments: {
               },
             },
           }.to_json,
           headers: {
             "HTTP_AUTHORIZATION" => "Bearer #{token}",
             "CONTENT_TYPE" => "application/json",
             "HTTP_ACCEPT" => "application/json, text/event-stream",
             "HTTP_MCP_PROTOCOL_VERSION" => DiscourseMcp::LEGACY_PROTOCOL_VERSION,
           },
           env: {
             "rack.hijack" => -> { io },
           }
      expect(response.status).not_to eq(418)
      expect(response.parsed_body.dig("error", "message")).to eq(
        I18n.t("mcp.errors.content_policy_blocked"),
      )
      expect(response.headers["WWW-Authenticate"]).to be_nil
      expect(McpAuditLog.last).to have_attributes(
        tool: "oracle_deferred",
        outcome: "content_policy_blocked",
      )
    end
    expect(io.string).to eq("")
    expect(invoked).to eq([])
  end
end
