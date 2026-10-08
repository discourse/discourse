# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::ToolRegistry do
  before { enable_current_plugin }

  describe ".refresh!" do
    it "discovers and caches tools from a modern-only server" do
      server = Fabricate(:ai_mcp_server, url: "https://mcp.example.com")
      AiMcpServer.stubs(:validate_hostname_public!).returns(true)
      stub_request(:post, server.url).to_return do |request|
        result =
          if JSON.parse(request.body)["method"] == "server/discover"
            { supportedVersions: ["2026-07-28"], capabilities: { tools: {} } }
          else
            { tools: [{ name: "search", inputSchema: { type: "object" } }] }
          end
        { status: 200, body: { jsonrpc: "2.0", result: result }.to_json }
      end

      definitions = described_class.refresh!(server, raise_on_error: true)

      expect(definitions.pluck("name")).to eq(["search"])
      expect(server.reload.protocol_version).to eq("2026-07-28")
      expect(server.last_health_status).to eq("healthy")
      expect(
        a_request(:post, server.url).with do |request|
          JSON.parse(request.body)["method"] == "initialize"
        end,
      ).not_to have_been_made
    end
  end

  describe ".cache_key" do
    it "namespaces the cache by current multisite database" do
      RailsMultisite::ConnectionManagement.stubs(:current_db).returns("second")

      expect(described_class.cache_key(42)).to eq("discourse-ai:mcp-tools:v1:second:42")
    end
  end

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
