# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::Client do
  fab!(:ai_secret)
  fab!(:server) { Fabricate(:ai_mcp_server, ai_secret: ai_secret, url: "https://mcp.example.com") }

  before do
    enable_current_plugin
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
  end

  describe "#initialize_session" do
    it "initializes a session and notifies the server" do
      stub_request(:post, server.url).to_return(
        {
          status: 200,
          body: <<~SSE,
            event: message
            data: {"jsonrpc":"2.0","result":{"protocolVersion":"2025-03-26","capabilities":{"tools":{}}}}

          SSE
          headers: {
            "Content-Type" => "text/event-stream",
            "Mcp-Session-Id" => "session-1",
          },
        },
        { status: 202, body: "", headers: { "Content-Type" => "application/json" } },
      )

      result = described_class.new(server).initialize_session

      expect(result).to eq(
        session_id: "session-1",
        result: {
          "protocolVersion" => "2025-03-26",
          "capabilities" => {
            "tools" => {
            },
          },
        },
      )

      expect(
        a_request(:post, server.url).with do |request|
          payload = JSON.parse(request.body)

          payload["method"] == "initialize" &&
            request.headers["Accept"] == "application/json, text/event-stream" &&
            request.headers["Authorization"] == "Bearer #{ai_secret.secret}"
        end,
      ).to have_been_made.once

      expect(
        a_request(:post, server.url).with do |request|
          payload = JSON.parse(request.body)

          payload["method"] == "notifications/initialized" &&
            request.headers["Accept"] == "application/json, text/event-stream" &&
            request.headers["Mcp-Session-Id"] == "session-1"
        end,
      ).to have_been_made.once
    end
  end

  describe "#call_tool" do
    it "parses streamable HTTP SSE responses with CRLF separators" do
      stub_request(:post, server.url).to_return(
        status: 200,
        body: [
          %(event: message\r\ndata: {"jsonrpc":"2.0","params":{"progress":0.5}}\r\n\r\n),
          %(event: message\r\ndata: {"jsonrpc":"2.0","result":{"content":[{"type":"text","text":"Hello from MCP"}]}}\r\n\r\n),
          %(data: [DONE]\r\n\r\n),
        ].join,
        headers: {
          "Content-Type" => "text/event-stream",
        },
      )

      result = described_class.new(server).call_tool("lookup", { id: 1 }, session_id: "session-1")

      expect(result).to eq("content" => [{ "type" => "text", "text" => "Hello from MCP" }])
    end

    it "raises when a session expires" do
      stub_request(:post, server.url).to_return(
        status: 404,
        body: "",
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect do
        described_class.new(server).call_tool("lookup", {}, session_id: "session-1")
      end.to raise_error(
        described_class::SessionExpiredError,
        I18n.t("discourse_ai.mcp_servers.errors.session_expired"),
      )
    end
  end

  describe "OAuth flows" do
    it "raises an authorization error when OAuth authorization is required" do
      server.update!(auth_type: "oauth", ai_secret_id: nil, oauth_status: "disconnected")
      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: server.url,
          resource_metadata_url: "#{server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
        )

      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)
      stub_request(:post, server.url).to_return(
        status: 401,
        body: "",
        headers: {
          "Content-Type" => "application/json",
          "WWW-Authenticate" =>
            'Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource"',
        },
      )

      expect { described_class.new(server).initialize_session }.to raise_error(
        described_class::AuthorizationRequiredError,
        I18n.t(
          "discourse_ai.mcp_servers.errors.oauth_authorization_required",
          issuer: "https://auth.example.com",
        ),
      )
    end

    it "refreshes once and retries when an OAuth token is rejected" do
      server.update!(auth_type: "oauth", ai_secret_id: nil, oauth_status: "connected")
      server.oauth_token_store.write!(
        access_token: "expired-access-token",
        refresh_token: "refresh-token",
      )

      server.stubs(:auth_header_value).returns(
        "Bearer expired-access-token",
        "Bearer fresh-access-token",
        "Bearer fresh-access-token",
      )
      DiscourseAi::Mcp::OAuthFlow.expects(:refresh!).with(server).once

      stub_request(:post, server.url).to_return(
        { status: 401, body: "", headers: { "Content-Type" => "application/json" } },
        {
          status: 200,
          body: {
            jsonrpc: "2.0",
            result: {
              protocolVersion: "2025-03-26",
              capabilities: {
                tools: {
                },
              },
            },
          }.to_json,
          headers: {
            "Content-Type" => "application/json",
            "Mcp-Session-Id" => "session-2",
          },
        },
        { status: 202, body: "", headers: { "Content-Type" => "application/json" } },
      )

      result = described_class.new(server).initialize_session

      expect(result[:session_id]).to eq("session-2")
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).to have_been_made.twice
    end
  end

  it "rejects non-public endpoints at request time" do
    insecure_server = Fabricate.build(:ai_mcp_server, url: "https://localhost/mcp")
    AiMcpServer
      .expects(:validate_hostname_public!)
      .with("localhost")
      .raises(FinalDestination::SSRFError, "localhost is not allowed")

    expect { described_class.new(insecure_server).initialize_session }.to raise_error(
      described_class::Error,
      I18n.t("discourse_ai.mcp_servers.invalid_url_not_reachable"),
    )
  end
end
