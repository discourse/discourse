# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::Mcp do
  fab!(:user)
  fab!(:ai_mcp_server)

  before { enable_current_plugin }

  def tool_class
    described_class.class_instance(
      ai_mcp_server.id,
      "search_issues",
      {
        "title" => "Search issues",
        "name" => "search_issues",
        "description" => "Search issues across external MCP data sources.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "query" => {
              "type" => "string",
              "description" => "Search query",
            },
          },
          "required" => ["query"],
        },
      },
    )
  end

  it "passes through the raw JSON schema with anyOf/oneOf/allOf/$ref resolved" do
    klass =
      described_class.class_instance(
        ai_mcp_server.id,
        "search",
        {
          "name" => "search",
          "description" => "Search",
          "inputSchema" => {
            "type" => "object",
            "$defs" => {
              "StatusFilter" => {
                "type" => "object",
                "properties" => {
                  "status" => {
                    "type" => "string",
                  },
                },
              },
            },
            "properties" => {
              "places" => {
                "anyOf" => [
                  { "items" => { "type" => "string" }, "type" => "array" },
                  { "type" => "null" },
                ],
                "default" => nil,
              },
              "mode" => {
                "oneOf" => [{ "type" => "integer" }, { "type" => "null" }],
              },
              "ids" => {
                "type" => "array",
                "items" => {
                  "anyOf" => [{ "type" => "integer" }, { "type" => "null" }],
                },
              },
              "sort" => {
                "anyOf" => [{ "type" => "string", "enum" => %w[asc desc] }, { "type" => "null" }],
                "description" => "Sort order",
              },
              "filter" => {
                "$ref" => "#/$defs/StatusFilter",
              },
              "combined" => {
                "allOf" => [
                  { "type" => "object", "properties" => { "a" => { "type" => "string" } } },
                  { "properties" => { "b" => { "type" => "integer" } }, "required" => ["b"] },
                ],
              },
            },
            "required" => %w[places],
          },
        },
      )

    sig = klass.signature
    schema = sig[:json_schema]

    expect(schema[:properties][:places][:type]).to eq("array")
    expect(schema[:properties][:places][:items]).to eq({ type: "string" })

    expect(schema[:properties][:mode][:type]).to eq("integer")

    expect(schema[:properties][:ids][:type]).to eq("array")
    expect(schema[:properties][:ids][:items][:type]).to eq("integer")

    expect(schema[:properties][:sort][:type]).to eq("string")
    expect(schema[:properties][:sort][:enum]).to eq(%w[asc desc])
    expect(schema[:properties][:sort][:description]).to eq("Sort order")

    expect(schema[:properties][:filter][:type]).to eq("object")
    expect(schema[:properties][:filter][:properties][:status][:type]).to eq("string")

    expect(schema[:properties][:combined][:type]).to eq("object")
    expect(schema[:properties][:combined][:properties][:a][:type]).to eq("string")
    expect(schema[:properties][:combined][:properties][:b][:type]).to eq("integer")
    expect(schema[:properties][:combined][:required]).to eq(["b"])

    expect(schema[:required]).to eq(%w[places])
    expect(schema).not_to have_key(:$defs)
  end

  it "uses a short title in thinking summaries and renders the invocation parameters in details" do
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil)

    expect(tool.summary).to eq("Search issues")
    expect(tool.details).to eq("query: bug")
  end

  it "invokes the remote tool and stores the turn session" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:initialize_session)
      .returns({ session_id: "session-1", result: { "protocolVersion" => "2025-11-25" } })
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:call_tool)
      .returns({ "content" => [{ "type" => "text", "text" => "Found results" }] })

    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    expect(tool.invoke).to eq({ result: "Found results" })
    expect(context.mcp_session_for(ai_mcp_server.id)).to eq("session-1")
  end

  it "reuses the same turn session across multiple invocations" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:initialize_session)
      .returns({ session_id: "session-1", result: { "protocolVersion" => "2025-11-25" } })
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:call_tool)
      .returns({ "content" => [{ "type" => "text", "text" => "Found results" }] })

    first = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)
    second = tool_class.new({ query: "feature" }, bot_user: user, llm: nil, context: context)

    expect(first.invoke).to eq({ result: "Found results" })
    expect(second.invoke).to eq({ result: "Found results" })
    expect(context.mcp_session_for(ai_mcp_server.id)).to eq("session-1")
  end

  it "reuses a negotiated version and session ID across client instances" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    stub_request(:post, ai_mcp_server.url).to_return do |request|
      method = JSON.parse(request.body)["method"]
      case method
      when "server/discover"
        { status: 400, body: "" }
      when "initialize"
        {
          status: 200,
          body: { result: { protocolVersion: "2025-03-26" } }.to_json,
          headers: {
            "Mcp-Session-Id" => "session-1",
          },
        }
      when "notifications/initialized"
        { status: 202 }
      else
        { status: 200, body: { result: { content: [{ type: "text", text: "Found" }] } }.to_json }
      end
    end

    2.times do
      tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)
      expect(tool.invoke).to eq(result: "Found")
    end

    expect(context.mcp_session_for(ai_mcp_server.id)).to eq("session-1")
    expect(context.mcp_protocol_version_for(ai_mcp_server.id)).to eq("2025-03-26")
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        JSON.parse(request.body)["method"] == "initialize"
      end,
    ).to have_been_made.once
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        JSON.parse(request.body)["method"] == "tools/call" &&
          request.headers["Mcp-Protocol-Version"] == "2025-03-26" &&
          request.headers["Mcp-Session-Id"] == "session-1"
      end,
    ).to have_been_made.twice
  end

  it "reuses a negotiated version for a stateless server across client instances" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    stub_request(:post, ai_mcp_server.url).to_return do |request|
      method = JSON.parse(request.body)["method"]
      case method
      when "server/discover"
        { status: 400, body: "" }
      when "initialize"
        { status: 200, body: { result: { protocolVersion: "2025-11-25" } }.to_json }
      when "notifications/initialized"
        { status: 202 }
      else
        { status: 200, body: { result: { content: [{ type: "text", text: "Found" }] } }.to_json }
      end
    end

    2.times do
      tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)
      expect(tool.invoke).to eq(result: "Found")
    end

    expect(context.mcp_session_for(ai_mcp_server.id)).to be_nil
    expect(context.mcp_protocol_version_for(ai_mcp_server.id)).to eq("2025-11-25")
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        JSON.parse(request.body)["method"] == "initialize"
      end,
    ).to have_been_made.once
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        JSON.parse(request.body)["method"] == "tools/call" &&
          request.headers["Mcp-Protocol-Version"] == "2025-11-25" &&
          request.headers["Mcp-Session-Id"].nil?
      end,
    ).to have_been_made.twice
  end

  it "reuses modern stateless negotiation across tool invocations" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    stub_request(:post, ai_mcp_server.url).to_return do |request|
      result =
        if JSON.parse(request.body)["method"] == "server/discover"
          { supportedVersions: ["2026-07-28"], capabilities: {} }
        else
          { content: [{ type: "text", text: "Found" }] }
        end
      { status: 200, body: { jsonrpc: "2.0", result: result }.to_json }
    end

    2.times do
      tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)
      expect(tool.invoke).to eq(result: "Found")
    end

    expect(context.mcp_session_for(ai_mcp_server.id)).to be_nil
    expect(context.mcp_protocol_version_for(ai_mcp_server.id)).to eq("2026-07-28")
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        JSON.parse(request.body)["method"] == "server/discover"
      end,
    ).to have_been_made.once
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        body = JSON.parse(request.body)
        body["method"] == "tools/call" &&
          body.dig("params", "_meta", "io.modelcontextprotocol/protocolVersion") == "2026-07-28" &&
          request.headers["Mcp-Protocol-Version"] == "2026-07-28" &&
          request.headers["Mcp-Method"] == "tools/call" &&
          request.headers["Mcp-Name"] == "search_issues" && request.headers["Mcp-Session-Id"].nil?
      end,
    ).to have_been_made.twice
  end

  it "renegotiates once after a classic session expires on the wire" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    initialization_count = 0
    stub_request(:post, ai_mcp_server.url).to_return do |request|
      case JSON.parse(request.body)["method"]
      when "server/discover"
        { status: 400, body: "" }
      when "initialize"
        initialization_count += 1
        {
          status: 200,
          body: { result: { protocolVersion: "2025-03-26" } }.to_json,
          headers: {
            "Mcp-Session-Id" => "session-#{initialization_count}",
          },
        }
      when "notifications/initialized"
        { status: 202 }
      when "tools/call"
        if request.headers["Mcp-Session-Id"] == "session-1"
          { status: 404, body: "" }
        else
          { status: 200, body: { result: { content: [{ type: "text", text: "Found" }] } }.to_json }
        end
      end
    end

    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    expect(tool.invoke).to eq(result: "Found")
    expect(context.mcp_session_for(ai_mcp_server.id)).to eq("session-2")
    expect(context.mcp_protocol_version_for(ai_mcp_server.id)).to eq("2025-03-26")
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        JSON.parse(request.body)["method"] == "tools/call" &&
          %w[session-1 session-2].include?(request.headers["Mcp-Session-Id"])
      end,
    ).to have_been_made.twice
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        JSON.parse(request.body)["method"] == "initialize"
      end,
    ).to have_been_made.twice
  end

  it "stops retrying when the replacement classic session also expires" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    initialization_count = 0
    stub_request(:post, ai_mcp_server.url).to_return do |request|
      case JSON.parse(request.body)["method"]
      when "server/discover"
        { status: 400, body: "" }
      when "initialize"
        initialization_count += 1
        {
          status: 200,
          body: { result: { protocolVersion: "2025-03-26" } }.to_json,
          headers: {
            "Mcp-Session-Id" => "session-#{initialization_count}",
          },
        }
      when "notifications/initialized"
        { status: 202 }
      when "tools/call"
        { status: 404, body: "" }
      end
    end

    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.session_expired"),
    )
    expect(
      a_request(:post, ai_mcp_server.url).with do |request|
        JSON.parse(request.body)["method"] == "tools/call"
      end,
    ).to have_been_made.twice
    expect(initialization_count).to eq(2)
  end

  it "returns invalid annotated arguments as model-visible errors without calling the server" do
    klass = tool_class
    klass.schema_value["inputSchema"]["properties"]["query"]["x-mcp-header"] = "Query"
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2026-07-28")
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)

    tool = klass.new({ query: 123 }, bot_user: user, llm: nil, context: context)

    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.invalid_annotated_argument"),
    )
    expect(a_request(:post, ai_mcp_server.url)).not_to have_been_made
  end

  it "returns HTTP and protocol failures as model-visible errors and allows another invocation" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2026-07-28")
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    [403, 500, 400].each do |status|
      message = "Tool request rejected with status #{status}"
      stub_request(:post, ai_mcp_server.url).to_return(
        {
          status: status,
          body: { jsonrpc: "2.0", error: { code: -32_001, message: message } }.to_json,
        },
        {
          status: 200,
          body: { result: { content: [{ type: "text", text: "Recovered" }] } }.to_json,
        },
      )

      expect(tool.invoke).to eq(status: "error", error: message)
      expect(tool.invoke).to eq(result: "Recovered")
    end
  end

  it "returns connection failures, timeouts, and malformed responses as model-visible errors" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2026-07-28")
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    stub_request(:post, ai_mcp_server.url).to_raise(Errno::ECONNREFUSED)
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.connection_failed"),
    )

    stub_request(:post, ai_mcp_server.url).to_timeout
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.timeout"),
    )

    stub_request(:post, ai_mcp_server.url).to_raise(Net::WriteTimeout)
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.timeout"),
    )

    stub_request(:post, ai_mcp_server.url).to_raise(OpenSSL::SSL::SSLError)
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.connection_failed"),
    )

    stub_request(:post, ai_mcp_server.url).to_return(status: 200, body: "invalid JSON")
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.invalid_response"),
    )

    stub_request(:post, ai_mcp_server.url).to_return(status: 502, body: "<html>Bad gateway</html>")
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.request_failed", status: 502),
    )
  end

  it "records connection failures for admins once and logs only when they change" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2026-07-28")
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
    stub_request(:post, ai_mcp_server.url).to_raise(
      FinalDestination::SSRFDetector::DisallowedIpError,
    )
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    first_logs = track_log_messages { tool.invoke }
    repeat_logs = track_log_messages { tool.invoke }

    ai_mcp_server.reload
    expect(ai_mcp_server.last_health_status).to eq("error")
    expect(ai_mcp_server.last_health_error).to eq(
      I18n.t("discourse_ai.mcp_servers.errors.connection_blocked"),
    )
    expect(first_logs.warnings.size).to eq(1)
    expect(repeat_logs.warnings).to be_empty
  end

  it "hides disallowed-address diagnostics from the model but logs them" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2026-07-28")
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
    stub_request(:post, ai_mcp_server.url).to_raise(
      FinalDestination::SSRFDetector::DisallowedIpError,
    )
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    result = nil
    logs = track_log_messages { result = tool.invoke }

    expect(result).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.connection_failed"),
    )
    expect(logs.warnings.join).to include(
      I18n.t("discourse_ai.mcp_servers.errors.connection_blocked"),
    )
  end

  it "hides request-time address validation failures from the model" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2026-07-28")
    ai_mcp_server.update_columns(url: "https://10.0.0.1/mcp")
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    result = nil
    logs = track_log_messages { result = tool.invoke }

    expect(result).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.connection_failed"),
    )
    expect(logs.warnings.join).to include(
      I18n.t("discourse_ai.mcp_servers.invalid_url_not_reachable"),
    )
    expect(a_request(:post, ai_mcp_server.url)).not_to have_been_made
  end

  context "when the OAuth token endpoint is unreachable" do
    let(:token_endpoint) { "https://auth.example.com/token" }
    let(:context) { DiscourseAi::Agents::BotContext.new(messages: []) }
    let(:tool) { tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context) }

    before do
      context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2026-07-28")
      ai_mcp_server.update!(auth_type: "oauth", ai_secret_id: nil, oauth_status: "connected")
      ai_mcp_server.oauth_token_store.write!(access_token: "stale", refresh_token: "refresh")
      AiMcpServer.stubs(:validate_hostname_public!).returns(true)
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: token_endpoint,
          revocation_endpoint: nil,
        ),
      )
      stub_request(:post, token_endpoint).to_raise(Errno::ECONNREFUSED)
    end

    it "returns a connection failure when refreshing before the request" do
      ai_mcp_server.update_columns(oauth_access_token_expires_at: 1.minute.ago)

      expect(tool.invoke).to eq(
        status: "error",
        error: I18n.t("discourse_ai.mcp_servers.errors.connection_failed"),
      )
      expect(a_request(:post, ai_mcp_server.url)).not_to have_been_made
    end

    it "returns a connection failure when refreshing after a rejected token" do
      stub_request(:post, ai_mcp_server.url).to_return(status: 401, body: "")

      expect(tool.invoke).to eq(
        status: "error",
        error: I18n.t("discourse_ai.mcp_servers.errors.connection_failed"),
      )
      expect(a_request(:post, token_endpoint)).to have_been_made.once
    end

    it "returns a timeout when the token endpoint times out" do
      ai_mcp_server.update_columns(oauth_access_token_expires_at: 1.minute.ago)
      stub_request(:post, token_endpoint).to_timeout

      expect(tool.invoke).to eq(
        status: "error",
        error: I18n.t("discourse_ai.mcp_servers.errors.timeout"),
      )
    end
  end

  it "asks for an administrator reconnect when authorization is required" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    detail =
      I18n.t(
        "discourse_ai.mcp_servers.errors.oauth_authorization_required",
        issuer: "https://auth.example.com",
      )
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:initialize_session)
      .raises(DiscourseAi::Mcp::Client::AuthorizationRequiredError, detail)
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    result = nil
    logs = track_log_messages { result = tool.invoke }

    expect(result).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.reconnect_required"),
    )
    expect(logs.warnings.join).to include(detail)
    expect(ai_mcp_server.reload.last_health_error).to eq(detail)
  end

  it "asks for an administrator reconnect when an OAuth refresh fails" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    ai_mcp_server.update!(auth_type: "oauth", ai_secret_id: nil, oauth_status: "connected")
    ai_mcp_server.oauth_token_store.write!(access_token: "expired", refresh_token: "refresh")
    ai_mcp_server.update_columns(oauth_access_token_expires_at: 1.minute.ago)
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
    detail = I18n.t("discourse_ai.mcp_servers.errors.oauth_token_exchange_failed", status: 400)
    DiscourseAi::Mcp::OAuthFlow.stubs(:refresh!).raises(DiscourseAi::Mcp::Client::Error, detail)
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.reconnect_required"),
    )
    expect(a_request(:post, ai_mcp_server.url)).not_to have_been_made
  end

  it "returns tool execution errors as text the model can inspect" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:initialize_session)
      .returns({ session_id: "session-1", result: { "protocolVersion" => "2025-11-25" } })
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:call_tool)
      .returns(
        {
          "content" => [{ "type" => "text", "text" => "Not found: Project google.com:chops-prod" }],
          "isError" => true,
        },
      )

    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    expect(tool.invoke).to eq(
      { status: "error", error: "Not found: Project google.com:chops-prod" },
    )
  end

  it "stops identical failures without treating distinct batch inputs as retries" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2025-11-25")
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
    message = "Record not found"
    stub_request(:post, ai_mcp_server.url).to_return(
      status: 200,
      body: { result: { isError: true, content: [{ type: "text", text: message }] } }.to_json,
    )

    8.times do |index|
      tool = tool_class.new({ query: "item-#{index}" }, bot_user: user, llm: nil, context: context)
      expect(tool.invoke).to eq(status: "error", error: message)
    end
    expect(context.mcp_failure_limit_reached?).to eq(false)

    tool = tool_class.new({ query: "same-item" }, bot_user: user, llm: nil, context: context)
    3.times { expect(tool.invoke).to eq(status: "error", error: message) }
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.failure_limit"),
    )
    expect(a_request(:post, ai_mcp_server.url)).to have_been_made.times(11)
  end

  it "counts authorization and blocked connection failures toward the limit" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:initialize_session)
      .raises(DiscourseAi::Mcp::Client::AuthorizationRequiredError, "auth required")
      .then
      .raises(DiscourseAi::Mcp::Client::AuthorizationRequiredError, "auth required")
      .then
      .raises(DiscourseAi::Mcp::Client::ConnectionBlockedError, "blocked")
      .then
      .raises(DiscourseAi::Mcp::Client::ConnectionBlockedError, "blocked")
      .then
      .raises(DiscourseAi::Mcp::Client::AuthorizationRequiredError, "auth required")
    tool = tool_class.new({ query: "bug" }, bot_user: user, llm: nil, context: context)

    4.times { tool.invoke }
    expect(context.mcp_failure_limit_reached?).to eq(false)

    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_servers.errors.reconnect_required"),
    )
    expect(context.mcp_failure_limit_reached?).to eq(true)
  end

  it "allows a corrected call after a success resets failures for that input" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.store_mcp_session(ai_mcp_server.id, nil, protocol_version: "2025-11-25")
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
    failure = {
      status: 200,
      body: { result: { isError: true, content: [{ type: "text", text: "Unavailable" }] } }.to_json,
    }
    success = {
      status: 200,
      body: { result: { content: [{ type: "text", text: "Recovered" }] } }.to_json,
    }
    stub_request(:post, ai_mcp_server.url).to_return(failure, failure, success, failure, failure)
    tool = tool_class.new({ query: "item" }, bot_user: user, llm: nil, context: context)

    2.times { expect(tool.invoke[:status]).to eq("error") }
    expect(tool.invoke).to eq(result: "Recovered")
    2.times { expect(tool.invoke[:status]).to eq("error") }
    expect(context.mcp_failure_limit_reached?).to eq(false)
  end
end
