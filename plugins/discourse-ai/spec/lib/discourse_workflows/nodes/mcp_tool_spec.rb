# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::McpTool::V1 do
  fab!(:server) { Fabricate(:ai_mcp_server, auth_type: "none") }
  fab!(:other_server) { Fabricate(:ai_mcp_server, auth_type: "none") }

  let(:schema) do
    {
      type: "object",
      properties: {
        city: {
          type: "string",
        },
        metric: {
          type: "boolean",
        },
      },
      required: %w[city metric],
      additionalProperties: false,
    }
  end

  let(:configuration) do
    {
      "mcp_server_id" => server.id,
      "tool_name" => "forecast",
      "arguments" => {
        "city" => "={{ $json.city }}",
        "metric" => false,
      },
    }
  end

  before do
    SiteSetting.discourse_ai_enabled = true
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
    stub_server(server, "forecast")
    stub_server(other_server, "lookup")
  end

  def stub_server(server, name)
    stub_request(:post, server.url).to_return do |request|
      body = JSON.parse(request.body)
      result =
        case body.fetch("method")
        when "server/discover"
          {
            supportedVersions: [DiscourseAi::Mcp::Client::MODERN_PROTOCOL_VERSION],
            capabilities: {
              tools: {
              },
            },
          }
        when "tools/list"
          { tools: [{ name: name, title: name.capitalize, inputSchema: schema }] }
        when "tools/call"
          arguments = body.fetch("params").fetch("arguments")
          {
            content: [
              { type: "text", text: "#{arguments.fetch("city")}: #{arguments.fetch("metric")}" },
            ],
          }
        end
      { status: 200, body: { jsonrpc: "2.0", id: body["id"], result: result }.to_json }
    end
  end

  def options(method_name, parameters = {})
    described_class.load_options_context(
      DiscourseWorkflows::LoadOptionsContext.new(method_name:, parameters:),
    )
  end

  it "loads only the selected server's tools and their argument definitions" do
    expect(options("servers").pluck(:id)).to contain_exactly(server.id, other_server.id)
    expect(options("tools", mcp_server_id: other_server.id)).to eq(
      [{ id: "lookup", name: "Lookup" }],
    )
    expect(options("tool_arguments", mcp_server_id: server.id, tool_name: "forecast")).to eq(
      [
        { name: "city", required: true, type: "string" },
        { name: "metric", required: true, type: "boolean" },
      ],
    )
  end

  it "calls the existing MCP runtime with resolved arguments and returns paired output" do
    items =
      execute_node_output(
        configuration:,
        input_items: %w[Lisbon Tokyo].map { |city| { "json" => { "city" => city } } },
      ).first

    expect(items.map { |item| item.fetch("json") }).to eq(
      [{ "result" => "Lisbon: false" }, { "result" => "Tokyo: false" }],
    )
    expect(items.pluck("pairedItem")).to eq([{ "item" => 0 }, { "item" => 1 }])
    expect(items.first.fetch("json")).to match_node_output_schema(described_class, configuration:)
  end

  it "validates every item before making any remote tool calls" do
    expect {
      execute_node_output(
        configuration:,
        input_items: [{ "json" => { "city" => "Lisbon" } }, { "json" => { "city" => 42 } }],
      )
    }.to raise_error(DiscourseWorkflows::NodeError, /arguments are invalid.*item 1/)
    expect(
      a_request(:post, server.url).with do |request|
        JSON.parse(request.body)["method"] == "tools/call"
      end,
    ).not_to have_been_made
  end

  it "does not run an existing reference after its server is disabled" do
    server.update!(enabled: false)

    expect(options("servers").pluck(:id)).to eq([other_server.id])
    expect { execute_node(configuration:) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /not available/,
    )
  end
end
