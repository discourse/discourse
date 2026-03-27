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
    expect(schema).not_to have_key(:"$defs")
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
      .returns({ session_id: "session-1", result: {} })
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
      .returns({ session_id: "session-1", result: {} })
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

  it "returns tool execution errors as text the model can inspect" do
    context = DiscourseAi::Agents::BotContext.new(messages: [])
    DiscourseAi::Mcp::Client
      .any_instance
      .stubs(:initialize_session)
      .returns({ session_id: "session-1", result: {} })
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
