# frozen_string_literal: true

RSpec.describe AiAgentMcpServer do
  fab!(:ai_mcp_server)

  before { enable_current_plugin }

  it "memoizes serialized tools for count calculations" do
    ai_mcp_server
      .expects(:tools_for_serialization)
      .once
      .returns(
        [{ name: "search_issues", token_count: 3 }, { name: "create_issue", token_count: 5 }],
      )

    assignment =
      described_class.new(ai_mcp_server: ai_mcp_server, selected_tool_names: ["search_issues"])

    expect(assignment.tools_for_serialization).to eq([{ name: "search_issues", token_count: 3 }])
    expect(assignment.tool_count).to eq(1)
    expect(assignment.token_count).to eq(3)
  end
end
