# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowScriptContext do
  fab!(:admin)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |builder|
        builder.node "post-created", "trigger:post_created"
        builder.node "filter", "condition:filter"
        builder.node "code", "action:code"
        builder.connect "post-created", "filter"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      **graph,
      pin_data: {
        "Code" => [{ "json" => { "custom" => { "id" => 1 }, "nothing" => nil } }],
      },
    )
  end

  def invoke_tool(upstream_node_id)
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    described_class.new(
      { workflow_id: workflow.id, upstream_node_id: upstream_node_id },
      bot_user: Discourse.system_user,
      llm: nil,
      context: context,
    ).invoke
  end

  it "uses the node's declared fields before it has run" do
    result = invoke_tool("post-created")

    expect(result.dig(:upstream_fields, :output_fields, 0)).to include(
      "post.id" => "integer",
      "user.username" => "string",
    )
    expect(result.dig(:upstream_fields, :output_fields, 0)).not_to include("pinned_only")
  end

  it "uses pinned fields before the node's declaration" do
    node_name = workflow.nodes.find { |node| node["id"] == "post-created" }["name"]
    workflow.update_node_pin_data!(node_name, [{ "json" => { "pinned_only" => true } }])

    result = invoke_tool("post-created")

    expect(result.dig(:upstream_fields, :output_fields, 0)).to eq("pinned_only" => "boolean")
  end

  it "keeps empty pinned JSON authoritative over the declaration" do
    node_name = workflow.nodes.find { |node| node["id"] == "post-created" }["name"]
    workflow.update_node_pin_data!(node_name, [{ "json" => {} }])

    result = invoke_tool("post-created")

    expect(result.dig(:upstream_fields, :output_fields)).to eq([{}])
  end

  it "resolves inherited fields for pass-through nodes" do
    result = invoke_tool("filter")

    expect(result.dig(:upstream_fields, :output_fields, 0)).to include(
      "post.id" => "integer",
      "user.username" => "string",
    )
  end

  it "infers fields from pin data when the node has no declaration" do
    result = invoke_tool("code")

    expect(result.dig(:upstream_fields, :output_fields, 0)).to eq(
      "custom" => "object",
      "custom.id" => "integer",
      "nothing" => "null",
    )
  end

  it "preserves unsafe property segments inferred from pin data" do
    workflow.update_node_pin_data!(
      "Code",
      [{ "json" => { "full-name" => "Ada", "a.b" => true, "a" => { "b" => 1 } } }],
    )

    result = invoke_tool("code")

    expect(result.dig(:upstream_fields, :output_fields, 0)).to eq(
      '["full-name"]' => "string",
      '["a.b"]' => "boolean",
      "a" => "object",
      "a.b" => "integer",
    )
  end
end
