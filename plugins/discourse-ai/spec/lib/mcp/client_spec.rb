# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::Client do
  fab!(:ai_secret)
  fab!(:server) { Fabricate(:ai_mcp_server, ai_secret: ai_secret, url: "https://mcp.example.com") }

  before do
    enable_current_plugin
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
  end

  def stub_oauth_refresh
    server.update!(auth_type: "oauth", ai_secret_id: nil, oauth_status: "connected")
    server.oauth_token_store.write!(access_token: "expired-token", refresh_token: "refresh-token")
    allow(DiscourseAi::Mcp::OAuthFlow).to receive(:refresh!).with(server) do
      server.oauth_token_store.write!(access_token: "fresh-token", refresh_token: "refresh-token")
    end
    stub_request(:post, server.url).with(
      headers: {
        "Authorization" => "Bearer expired-token",
      },
    ).to_return(status: 401, body: "")
  end

  describe "#initialize_classic_session" do
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

      result = described_class.new(server).initialize_classic_session

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
            payload.dig("params", "protocolVersion") == "2025-11-25" &&
            request.headers["Mcp-Protocol-Version"].nil? &&
            request.headers["Accept"] == "application/json, text/event-stream" &&
            request.headers["Authorization"] == "Bearer #{ai_secret.secret}"
        end,
      ).to have_been_made.once

      expect(
        a_request(:post, server.url).with do |request|
          payload = JSON.parse(request.body)

          payload["method"] == "notifications/initialized" &&
            request.headers["Mcp-Protocol-Version"] == "2025-03-26" &&
            request.headers["Accept"] == "application/json, text/event-stream" &&
            request.headers["Mcp-Session-Id"] == "session-1"
        end,
      ).to have_been_made.once
    end

    it "sends the negotiated 2025-03-26 version on subsequent requests" do
      stub_request(:post, server.url).to_return(
        {
          status: 200,
          body: { jsonrpc: "2.0", result: { protocolVersion: "2025-03-26" } }.to_json,
        },
        { status: 202, body: "" },
        { status: 200, body: { jsonrpc: "2.0", result: { tools: [] } }.to_json },
      )

      client = described_class.new(server)
      client.initialize_classic_session
      expect(client.list_tools).to eq([])
      expect(
        a_request(:post, server.url).with do |request|
          %w[notifications/initialized tools/list].include?(JSON.parse(request.body)["method"]) &&
            request.headers["Mcp-Protocol-Version"] == "2025-03-26"
        end,
      ).to have_been_made.twice
    end

    it "uses 2025-11-25 for external servers that select it" do
      stub_request(:post, server.url).to_return(
        {
          status: 200,
          body: { jsonrpc: "2.0", result: { protocolVersion: "2025-11-25" } }.to_json,
        },
        { status: 202, body: "" },
        { status: 200, body: { jsonrpc: "2.0", result: { tools: [] } }.to_json },
      )

      client = described_class.new(server)
      client.initialize_classic_session
      expect(client.list_tools).to eq([])
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "tools/list" &&
            request.headers["Mcp-Protocol-Version"] == "2025-11-25"
        end,
      ).to have_been_made.once
    end

    it "retries 2025-03-26 once when a legacy server explicitly rejects the latest offer" do
      [
        { status: 200, message: "Unsupported protocol version 2025-11-25" },
        { status: 400, message: "Protocol version 2025-11-25 is not supported" },
      ].each do |failure|
        stub_request(:post, server.url).to_return(
          {
            status: failure[:status],
            body: { jsonrpc: "2.0", error: { code: -32_602, message: failure[:message] } }.to_json,
          },
          { status: 200, body: { result: { protocolVersion: "2025-03-26" } }.to_json },
          { status: 202, body: "" },
        )

        result = described_class.new(server).initialize_classic_session
        expect(result[:result]["protocolVersion"]).to eq("2025-03-26")
      end
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body).dig("params", "protocolVersion") == "2025-03-26"
        end,
      ).to have_been_made.twice
    end

    it "does not retry classic initialization for unrelated errors" do
      [200, 400].each do |status|
        stub_request(:post, server.url).to_return(
          status: status,
          body: { jsonrpc: "2.0", error: { code: -32_602, message: "Invalid arguments" } }.to_json,
        )

        expect { described_class.new(server).initialize_classic_session }.to raise_error(
          described_class::Error,
          "Invalid arguments",
        )
      end
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).to have_been_made.twice
    end

    it "rejects a malformed classic initialize error instead of falling back" do
      stub_request(:post, server.url).to_return(status: 400, body: "not JSON")

      expect { described_class.new(server).initialize_classic_session }.to raise_error(
        described_class::Error,
        I18n.t("discourse_ai.mcp_servers.errors.invalid_response"),
      )
      expect(a_request(:post, server.url)).to have_been_made.once
    end

    it "rejects missing and unsupported initialize response versions without notifying" do
      [nil, "2026-07-28", "2025-06-18"].each do |version|
        stub_request(:post, server.url).to_return(
          status: 200,
          body: { jsonrpc: "2.0", result: { protocolVersion: version } }.to_json,
        )

        expect { described_class.new(server).initialize_classic_session }.to raise_error(
          described_class::Error,
          /MCP protocol version/,
        )
      end
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "notifications/initialized"
        end,
      ).not_to have_been_made
    end

    it "rejects an unsupported cached protocol version" do
      expect do described_class.new(server, protocol_version: "2026-08-01") end.to raise_error(
        described_class::Error,
        /Unsupported MCP protocol version/,
      )
    end
  end

  describe "dual-era negotiation" do
    it "uses stateless 2026-07-28 requests with matching metadata and safe annotated headers" do
      schema = {
        "type" => "object",
        "properties" => {
          "region" => {
            "type" => "string",
            "x-mcp-header" => "Region",
          },
          "options" => {
            "type" => "object",
            "properties" => {
              "urgent" => {
                "type" => "boolean",
                "x-mcp-header" => "Urgent",
              },
              "count" => {
                "type" => "integer",
                "x-mcp-header" => "Count",
              },
            },
          },
        },
      }
      stub_request(:post, server.url).to_return do |request|
        result =
          case JSON.parse(request.body)["method"]
          when "server/discover"
            { supportedVersions: ["2026-07-28"], capabilities: { tools: {} } }
          when "tools/list"
            { tools: [{ name: "sample", inputSchema: schema }] }
          else
            { content: [{ type: "text", text: "Done" }] }
          end
        { status: 200, body: { jsonrpc: "2.0", result: result }.to_json }
      end

      client = described_class.new(server)
      expect(client.initialize_session).to eq(
        session_id: nil,
        result: {
          "supportedVersions" => ["2026-07-28"],
          "capabilities" => {
            "tools" => {
            },
          },
          "protocolVersion" => "2026-07-28",
        },
      )
      expect(client.list_tools.pluck("name")).to eq(["sample"])
      expect(
        client.call_tool(
          "=?base64?literal?=",
          { region: "Hello, 世界", options: { urgent: false, count: 42 } },
          session_id: "ignored-legacy-session",
          input_schema: schema,
        ),
      ).to eq("content" => [{ "type" => "text", "text" => "Done" }])

      expect(
        a_request(:post, server.url).with do |request|
          body = JSON.parse(request.body)
          metadata = body.dig("params", "_meta")
          metadata["io.modelcontextprotocol/protocolVersion"] == "2026-07-28" &&
            metadata["io.modelcontextprotocol/clientCapabilities"] == {} &&
            metadata.dig("io.modelcontextprotocol/clientInfo", "name") ==
              described_class::USER_AGENT &&
            request.headers["Mcp-Protocol-Version"] == "2026-07-28" &&
            request.headers["Mcp-Method"] == body["method"] &&
            request.headers["Mcp-Session-Id"].nil?
        end,
      ).to have_been_made.times(3)
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "tools/call" &&
            request.headers["Mcp-Name"] == "=?base64?PT9iYXNlNjQ/bGl0ZXJhbD89?=" &&
            request.headers["Mcp-Param-Region"] == "=?base64?SGVsbG8sIOS4lueVjA==?=" &&
            request.headers["Mcp-Param-Urgent"] == "false" &&
            request.headers["Mcp-Param-Count"] == "42"
        end,
      ).to have_been_made.once
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).not_to have_been_made
    end

    it "falls back to classic initialize only after a non-modern 400 response" do
      stub_request(:post, server.url).to_return(
        { status: 400, body: "not JSON" },
        { status: 200, body: { result: { protocolVersion: "2025-03-26" } }.to_json },
        { status: 202, body: "" },
      )

      result = described_class.new(server).initialize_session

      expect(result[:result]["protocolVersion"]).to eq("2025-03-26")
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "server/discover" &&
            request.headers["Mcp-Protocol-Version"] == "2026-07-28"
        end,
      ).to have_been_made.once
      expect(
        a_request(:post, server.url).with do |request|
          body = JSON.parse(request.body)
          body["method"] == "initialize" && body.dig("params", "protocolVersion") == "2025-11-25" &&
            request.headers["Mcp-Protocol-Version"].nil?
        end,
      ).to have_been_made.once
    end

    it "falls back on a legacy JSON-RPC Invalid Request response to the modern probe" do
      stub_request(:post, server.url).to_return(
        {
          status: 400,
          body: { jsonrpc: "2.0", error: { code: -32_600, message: "Invalid Request" } }.to_json,
        },
        { status: 200, body: { result: { protocolVersion: "2025-03-26" } }.to_json },
        { status: 202, body: "" },
      )

      client = described_class.new(server)
      expect(client.initialize_session[:result]["protocolVersion"]).to eq("2025-03-26")
      expect(
        a_request(:post, server.url).with do |request|
          body = JSON.parse(request.body)
          body["method"] == "initialize" && request.headers["Mcp-Protocol-Version"].nil?
        end,
      ).to have_been_made.once
    end

    it "falls back when discovery returns JSON-RPC method not found with HTTP 200" do
      stub_request(:post, server.url).to_return(
        {
          status: 200,
          body: { jsonrpc: "2.0", error: { code: -32_601, message: "Method not found" } }.to_json,
        },
        { status: 200, body: { result: { protocolVersion: "2025-11-25" } }.to_json },
        { status: 202, body: "" },
      )

      result = described_class.new(server).initialize_session

      expect(result[:result]["protocolVersion"]).to eq("2025-11-25")
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).to have_been_made.once
    end

    it "falls back on bare HTTP 404 and 405 discovery responses" do
      [404, 405].each do |status|
        stub_request(:post, server.url).to_return(
          { status: status, body: "Not Found" },
          { status: 200, body: { result: { protocolVersion: "2025-03-26" } }.to_json },
          { status: 202, body: "" },
        )

        result = described_class.new(server).initialize_session
        expect(result[:result]["protocolVersion"]).to eq("2025-03-26")
      end
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).to have_been_made.twice
    end

    it "falls back on plain framework JSON 404 and 405 discovery responses" do
      [404, 405].each do |status|
        stub_request(:post, server.url).to_return(
          { status: status, body: { error: "Not Found" }.to_json },
          { status: 200, body: { result: { protocolVersion: "2025-03-26" } }.to_json },
          { status: 202, body: "" },
        )

        expect(described_class.new(server).initialize_session[:result]["protocolVersion"]).to eq(
          "2025-03-26",
        )
      end
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).to have_been_made.twice
    end

    it "does not fall back on unrelated discovery errors or recognized modern header errors" do
      [
        { status: 404, body: { jsonrpc: "2.0", error: { code: -32_000, message: "Busy" } } },
        {
          status: 404,
          body: {
            jsonrpc: "2.0",
            error: {
              code: -32_020,
              message: "Header mismatch",
            },
          },
        },
        {
          status: 405,
          body: {
            jsonrpc: "2.0",
            error: {
              code: -32_021,
              message: "Header mismatch",
            },
          },
        },
      ].each do |failure|
        stub_request(:post, server.url).to_return(
          status: failure[:status],
          body: failure[:body].to_json,
        )

        expect { described_class.new(server).initialize_session }.to raise_error(
          described_class::Error,
          /Busy|Header mismatch/,
        )
      end
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).not_to have_been_made
    end

    it "falls through to 2025-03-26 after an explicit legacy initialize rejection" do
      stub_request(:post, server.url).to_return(
        { status: 404, body: "" },
        {
          status: 400,
          body: {
            jsonrpc: "2.0",
            error: {
              code: -32_602,
              message: "Unsupported protocol version 2025-11-25",
            },
          }.to_json,
        },
        { status: 200, body: { result: { protocolVersion: "2025-03-26" } }.to_json },
        { status: 202, body: "" },
      )

      client = described_class.new(server)
      expect(client.initialize_session[:result]["protocolVersion"]).to eq("2025-03-26")
      expect(client.protocol_version).to eq("2025-03-26")
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body).dig("params", "protocolVersion") == "2025-03-26"
        end,
      ).to have_been_made.once
    end

    it "uses only an advertised classic version after a modern unsupported-version error" do
      stub_request(:post, server.url).to_return(
        {
          status: 400,
          body: {
            jsonrpc: "2.0",
            error: {
              code: -32_022,
              message: "Unsupported version",
              data: {
                supported: ["2025-03-26"],
              },
            },
          }.to_json,
        },
        { status: 200, body: { result: { protocolVersion: "2025-03-26" } }.to_json },
        { status: 202, body: "" },
      )

      expect(described_class.new(server).initialize_session[:result]["protocolVersion"]).to eq(
        "2025-03-26",
      )
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body).dig("params", "protocolVersion") == "2025-03-26"
        end,
      ).to have_been_made.once
    end

    it "never falls back for recognized modern errors without an advertised compatible version" do
      [
        { code: -32_022, data: { supported: ["2026-08-01"] } },
        { code: -32_020, data: { header: "Mcp-Method" } },
        { code: -32_021 },
      ].each do |error|
        stub_request(:post, server.url).to_return(
          status: 400,
          body: { jsonrpc: "2.0", error: error.merge(message: "Modern request rejected") }.to_json,
        )
        expect { described_class.new(server).initialize_session }.to raise_error(
          described_class::Error,
        )
      end
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).not_to have_been_made
    end

    it "rejects a successful discovery without the requested modern version" do
      stub_request(:post, server.url).to_return(
        status: 200,
        body: { jsonrpc: "2.0", result: { supportedVersions: ["2026-08-01"] } }.to_json,
      )

      expect { described_class.new(server).initialize_session }.to raise_error(
        described_class::Error,
        "Invalid MCP server/discover response",
      )
    end

    it "rejects malformed discovery response shapes" do
      [["unexpected"], 42, { result: [] }, { result: "unsupported" }].each do |payload|
        stub_request(:post, server.url).to_return(status: 200, body: payload.to_json)

        expect { described_class.new(server).initialize_session }.to raise_error(
          described_class::Error,
          I18n.t("discourse_ai.mcp_servers.errors.invalid_response"),
        )
      end
    end

    it "rejects invalid annotated tools rather than sending incomplete modern calls" do
      invalid_schema = {
        "type" => "object",
        "properties" => {
          "query" => {
            "type" => "string",
            "x-mcp-header" => "bad\r\nheader",
          },
        },
      }
      stub_request(:post, server.url).to_return(
        status: 200,
        body: {
          result: {
            tools: [
              { name: "invalid", inputSchema: invalid_schema },
              { name: "valid", inputSchema: { type: "object" } },
            ],
          },
        }.to_json,
      )

      client = described_class.new(server, protocol_version: "2026-07-28")
      expect(client.list_tools.pluck("name")).to eq(["valid"])
      expect do
        client.call_tool("invalid", { query: "secret" }, input_schema: invalid_schema)
      end.to raise_error(described_class::Error, "Invalid x-mcp-header annotation")
    end

    it "does not downgrade after a non-400 probe failure" do
      [403, 500].each do |status|
        stub_request(:post, server.url).to_return(
          status: status,
          body: { error: { message: "Denied" } }.to_json,
        )

        expect { described_class.new(server).initialize_session }.to raise_error(
          described_class::Error,
          "Denied",
        )
      end
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).not_to have_been_made
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
      expect(
        a_request(:post, server.url).with do |request|
          request.headers["Mcp-Protocol-Version"].nil?
        end,
      ).to have_been_made.once
    end

    it "returns tool execution errors from the response body even on non-2xx statuses" do
      stub_request(:post, server.url).to_return(
        status: 404,
        body: {
          jsonrpc: "2.0",
          result: {
            content: [{ type: "text", text: "Not found: Project google.com:chops-prod" }],
            isError: true,
          },
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      result = described_class.new(server).call_tool("lookup", { id: 1 })

      expect(result).to eq(
        "content" => [{ "type" => "text", "text" => "Not found: Project google.com:chops-prod" }],
        "isError" => true,
      )
    end

    it "still raises on transport failures without a tool result" do
      stub_request(:post, server.url).to_return(
        status: 500,
        body: "",
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect { described_class.new(server).call_tool("lookup", {}) }.to raise_error(
        described_class::Error,
        I18n.t("discourse_ai.mcp_servers.errors.request_failed", status: 500),
      )
    end

    it "preserves allow_result_error when retrying after an OAuth refresh" do
      stub_oauth_refresh
      stub_request(:post, server.url).with(
        headers: {
          "Authorization" => "Bearer fresh-token",
        },
      ).to_return(
        status: 404,
        body: {
          jsonrpc: "2.0",
          result: {
            content: [{ type: "text", text: "Not found: Project google.com:chops-prod" }],
            isError: true,
          },
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      result = described_class.new(server).call_tool("lookup", { id: 1 })

      expect(result).to eq(
        "content" => [{ "type" => "text", "text" => "Not found: Project google.com:chops-prod" }],
        "isError" => true,
      )
      expect(DiscourseAi::Mcp::OAuthFlow).to have_received(:refresh!).with(server).once
      expect(
        a_request(:post, server.url).with(headers: { "Authorization" => "Bearer expired-token" }),
      ).to have_been_made.once
      expect(
        a_request(:post, server.url).with(headers: { "Authorization" => "Bearer fresh-token" }),
      ).to have_been_made.once
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
      stub_oauth_refresh
      stub_request(:post, server.url).with(
        headers: {
          "Authorization" => "Bearer fresh-token",
        },
      ).to_return(
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

      result = described_class.new(server).initialize_classic_session

      expect(result[:session_id]).to eq("session-2")
      expect(DiscourseAi::Mcp::OAuthFlow).to have_received(:refresh!).with(server).once
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize" &&
            request.headers["Authorization"] == "Bearer expired-token"
        end,
      ).to have_been_made.once
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize" &&
            request.headers["Authorization"] == "Bearer fresh-token"
        end,
      ).to have_been_made.once
    end

    it "refreshes OAuth before retrying a modern discovery request" do
      stub_oauth_refresh
      stub_request(:post, server.url).with(
        headers: {
          "Authorization" => "Bearer fresh-token",
        },
      ).to_return(
        status: 200,
        body: { jsonrpc: "2.0", result: { supportedVersions: ["2026-07-28"] } }.to_json,
      )

      result = described_class.new(server).initialize_session

      expect(result[:result]["protocolVersion"]).to eq("2026-07-28")
      expect(DiscourseAi::Mcp::OAuthFlow).to have_received(:refresh!).with(server).once
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "server/discover" &&
            request.headers["Mcp-Protocol-Version"] == "2026-07-28" &&
            request.headers["Authorization"] == "Bearer expired-token"
        end,
      ).to have_been_made.once
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "server/discover" &&
            request.headers["Mcp-Protocol-Version"] == "2026-07-28" &&
            request.headers["Authorization"] == "Bearer fresh-token"
        end,
      ).to have_been_made.once
    end

    it "keeps classic initialization errors visible after an OAuth refresh" do
      stub_oauth_refresh
      stub_request(:post, server.url).with(
        headers: {
          "Authorization" => "Bearer fresh-token",
        },
      ).to_return(
        status: 400,
        body: { error: { code: -32_602, message: "Invalid arguments" } }.to_json,
      )

      expect { described_class.new(server).initialize_classic_session }.to raise_error(
        described_class::Error,
        "Invalid arguments",
      )
      expect(DiscourseAi::Mcp::OAuthFlow).to have_received(:refresh!).with(server).once
      expect(
        a_request(:post, server.url).with(headers: { "Authorization" => "Bearer expired-token" }),
      ).to have_been_made.once
      expect(
        a_request(:post, server.url).with(headers: { "Authorization" => "Bearer fresh-token" }),
      ).to have_been_made.once
    end

    it "keeps discovery fallback status tolerance after an OAuth refresh" do
      stub_oauth_refresh
      stub_request(:post, server.url).with(
        headers: {
          "Authorization" => "Bearer fresh-token",
        },
      ).to_return(
        { status: 400, body: "not JSON" },
        { status: 200, body: { result: { protocolVersion: "2025-03-26" } }.to_json },
        { status: 202, body: "" },
      )

      result = described_class.new(server).initialize_session

      expect(result[:result]["protocolVersion"]).to eq("2025-03-26")
      expect(DiscourseAi::Mcp::OAuthFlow).to have_received(:refresh!).with(server).once
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "server/discover" &&
            request.headers["Authorization"] == "Bearer expired-token"
        end,
      ).to have_been_made.once
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "server/discover" &&
            request.headers["Authorization"] == "Bearer fresh-token"
        end,
      ).to have_been_made.once
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
