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
end
