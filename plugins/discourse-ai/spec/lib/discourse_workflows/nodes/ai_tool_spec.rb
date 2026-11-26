# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::AiTool::V1 do
  fab!(:custom_tool) do
    Fabricate(
      :ai_tool,
      enabled: true,
      parameters: [
        { name: "headline", type: "string", required: true, enum: %w[News Events] },
        { name: "featured", type: "boolean", required: true },
      ],
      script: "function invoke(args) { return args; }",
    )
  end

  before { SiteSetting.discourse_ai_enabled = true }

  def options(method_name, parameters: {})
    described_class.load_options_context(
      DiscourseWorkflows::LoadOptionsContext.new(method_name:, parameters:),
    )
  end

  it "appears in the AI group of the node palette" do
    definitions =
      DiscourseWorkflows::NodeType::List.call!(guardian: Fabricate(:admin).guardian).node_types

    expect(definitions.pluck(:identifier)).to include("action:ai_tool")
  end

  it "lists reviewed live tools and returns their argument definitions" do
    SiteSetting.tagging_enabled = true
    reference = "custom:#{custom_tool.id}"

    expect(options("tools").pluck(:id)).to contain_exactly(
      "builtin:time",
      "builtin:categories",
      "builtin:users",
      "builtin:random_picker",
      "builtin:tags",
      "builtin:search",
      "builtin:read",
      "builtin:read_post",
      reference,
    )
    expect(options("tool_arguments", parameters: { tool_ref: reference })).to eq(
      [
        { name: "headline", type: "string", required: true, enum: %w[News Events] },
        { name: "featured", type: "boolean", required: true },
      ],
    )
  end

  it "calls the built-in once per item with the resolved arguments and pairs the results" do
    configuration = {
      "tool_ref" => "builtin:time",
      "arguments" => {
        "timezone" => "={{ $json.zone }}",
      },
    }
    items =
      execute_node_output(
        configuration:,
        input_items: %w[UTC Asia/Tokyo].map { |zone| { "json" => { "zone" => zone } } },
      ).first

    expect(items.map { |item| item.dig("json", "result", "args", "timezone") }).to eq(
      %w[UTC Asia/Tokyo],
    )
    expect(items.pluck("pairedItem")).to eq([{ "item" => 0 }, { "item" => 1 }])
    expect(items.first.fetch("json")).to match_node_output_schema(described_class, configuration:)
  end

  it "lists users matching the workflow's query and account status filters" do
    inactive_user = Fabricate(:inactive_user, username: "wf_roster_inactive")
    Fabricate(:user, username: "wf_roster_active")
    configuration = {
      "tool_ref" => "builtin:users",
      "arguments" => {
        "query" => "wf_roster",
        "active" => false,
      },
    }

    output = execute_node(configuration:)
    result = output.fetch("result")
    usernames =
      result.fetch("rows").map { |row| row.fetch(result.fetch("column_names").index("username")) }

    expect(usernames).to eq([inactive_user.username])
    expect(output).to match_node_output_schema(described_class, configuration:)
  end

  it "reads a public post without a configured model and refuses a private post" do
    public_post = Fabricate(:post)
    private_post = Fabricate(:post, topic: Fabricate(:private_message_topic))

    results =
      [public_post, private_post].map do |post|
        execute_node(
          configuration: {
            "tool_ref" => "builtin:read_post",
            "arguments" => {
              "topic_id" => post.topic_id,
              "post_number" => post.post_number,
            },
          },
        ).fetch("result")
      end

    expect(results.first).to include("status" => "ok", "content" => public_post.raw)
    expect(results.last).to include("status" => "not_found")
  end

  it "runs forum search with no configured model" do
    result =
      execute_node(
        configuration: {
          "tool_ref" => "builtin:search",
          "arguments" => {
            "search_query" => "gardening",
          },
        },
      ).fetch("result")

    expect(result).to include("rows" => [])
  end

  it "runs an enabled custom tool and preserves false" do
    configuration = {
      "tool_ref" => "custom:#{custom_tool.id}",
      "arguments" => {
        "headline" => "Events",
        "featured" => false,
      },
    }

    result = execute_node(configuration:)

    expect(result).to eq("result" => { "headline" => "Events", "featured" => false })
    expect(result).to match_node_output_schema(described_class, configuration:)
  end

  it "removes disabled custom tools from the picker and rejects saved references" do
    reference = "custom:#{custom_tool.id}"
    configuration = { "tool_ref" => reference }
    error = I18n.t("discourse_ai.discourse_workflows.ai_tool.errors.unavailable")

    expect(options("tools").pluck(:id)).to include(reference)

    custom_tool.update!(enabled: false)
    expect(options("tools").pluck(:id)).not_to include(reference)
    expect { execute_node(configuration:) }.to raise_error(DiscourseWorkflows::NodeError, error)
  end

  it "uses the custom tool's saved secret binding without exposing it in workflow data" do
    secret = Fabricate(:ai_secret)
    expected = OpenSSL::HMAC.hexdigest("SHA256", secret.secret, "workflow demo")
    custom_tool.update!(parameters: [], secret_contracts: [{ alias: "signing_key" }], script: <<~JS)
        function invoke() {
          return { verified: crypto.hmacSha256(secrets.get("signing_key"), "workflow demo") === "#{expected}" };
        }
      JS
    custom_tool.replace_secret_bindings!([{ alias: "signing_key", ai_secret_id: secret.id }])
    reference = "custom:#{custom_tool.id}"
    configuration = { "tool_ref" => reference }

    expect(options("tools").find { |option| option[:id] == reference }).to eq(
      id: reference,
      name: I18n.t("discourse_ai.tools.custom_name", name: custom_tool.name),
      custom: true,
    )
    expect(options("tool_arguments", parameters: configuration)).to eq([])

    output = execute_node(configuration:)
    expect(output).to eq("result" => { "verified" => true })
    expect(output).to match_node_output_schema(described_class, configuration:)
  end

  it "fails when a custom tool's required secret binding is missing" do
    custom_tool.update!(parameters: [], secret_contracts: [{ alias: "key" }])

    expect {
      execute_node(configuration: { "tool_ref" => "custom:#{custom_tool.id}" })
    }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(I18n.t("discourse_ai.discourse_workflows.ai_tool.errors.failed"))}/,
    )
  end

  it "rejects invalid arguments before invoking the tool" do
    expect do
      execute_node(
        configuration: {
          "tool_ref" => "builtin:random_picker",
          "arguments" => {
            "options" => [42],
          },
        },
      )
    end.to raise_error(DiscourseWorkflows::NodeError, /arguments are invalid.*item 0/)
  end
end
