# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::ToolRegistry do
  before { enable_current_plugin }

  describe ".tool_classes_for_servers" do
    fab!(:first_server) { Fabricate(:ai_mcp_server, name: "Jira") }
    fab!(:second_server) { Fabricate(:ai_mcp_server, name: "GitHub") }

    it "namespaces colliding tool names" do
      described_class
        .stubs(:tool_definitions_for)
        .with(first_server)
        .returns([{ "name" => "search", "description" => "Search Jira", "inputSchema" => {} }])
      described_class
        .stubs(:tool_definitions_for)
        .with(second_server)
        .returns([{ "name" => "search", "description" => "Search GitHub", "inputSchema" => {} }])

      classes =
        described_class.tool_classes_for_servers(
          [first_server, second_server],
          reserved_names: ["search"],
        )

      expect(classes.map { |klass| klass.signature[:name] }).to contain_exactly(
        "jira__search",
        "github__search",
      )
    end

    it "ignores disconnected oauth servers" do
      disconnected_oauth_server =
        Fabricate(
          :ai_mcp_server,
          name: "OAuth Docs",
          auth_type: "oauth",
          oauth_status: "disconnected",
        )

      described_class
        .stubs(:tool_definitions_for)
        .with(disconnected_oauth_server)
        .returns([{ "name" => "search", "description" => "Search docs", "inputSchema" => {} }])

      classes = described_class.tool_classes_for_servers([disconnected_oauth_server])

      expect(classes).to eq([])
    end

    it "filters tool classes by selected tool names" do
      described_class
        .stubs(:tool_definitions_for)
        .with(first_server)
        .returns(
          [
            { "name" => "search", "description" => "Search Jira", "inputSchema" => {} },
            { "name" => "create", "description" => "Create Jira", "inputSchema" => {} },
          ],
        )

      classes =
        described_class.tool_classes_for_servers(
          [first_server],
          selected_tool_names_by_server: {
            first_server.id => ["create"],
          },
        )

      expect(classes.map { |klass| klass.signature[:name] }).to eq(["create"])
    end
  end
end
