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

    expect { tool.invoke }.to raise_error(DiscourseAi::Mcp::Client::SessionExpiredError)
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
end
