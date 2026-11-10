# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowNodeDetails do
  fab!(:admin)

  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual", name: "Run"
        g.node "config-1",
               "action:code",
               name: "Configuration",
               parameters: {
                 mode: "runOnceForAllItems",
                 code: "return [{ json: { a: 1 } }];",
               }
        g.node "format-1", "action:code", name: "Format"
        g.chain "trigger-1", "config-1", "format-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end

  def invoke_tool(node_ids)
    described_class.new(
      { workflow_id: workflow.id, node_ids: node_ids },
      bot_user: Discourse.system_user,
      llm: nil,
      context: DiscourseAi::Agents::BotContext.new(messages: [], user: admin),
    ).invoke
  end

  def record_execution(runs)
    execution = Fabricate(:discourse_workflows_execution, workflow: workflow, status: :success)
    run_data =
      runs.to_h do |node_id, items|
        node = workflow.find_node(node_id)
        [
          node["name"],
          [
            {
              "node_id" => node_id,
              "node_name" => node["name"],
              "node_type" => node["type"],
              "status" => "success",
              "run_index" => 0,
              "inputs" => [],
              "outputs" => [{ "index" => 0, "items" => items, "item_count" => items.length }],
            },
          ],
        ]
      end
    Fabricate(
      :discourse_workflows_execution_data,
      execution: execution,
      data: {
        "run_data" => run_data,
      },
    )
    execution
  end

  it "returns parameters and connections for nodes found by id or name", :aggregate_failures do
    result = invoke_tool(%w[config-1 Format missing])
    config, format = result[:nodes]

    expect(result[:not_found]).to eq(["missing"])
    expect(config).to include(
      id: "config-1",
      type: "action:code",
      parameters: include("code" => "return [{ json: { a: 1 } }];"),
      incoming: [include(node_id: "trigger-1", node_name: "Run", output_index: 0)],
      outgoing: [include(node_id: "format-1", node_name: "Format")],
    )
    expect(format[:id]).to eq("format-1")
  end

  it "says when there is no recorded output" do
    expect(invoke_tool(["config-1"])[:nodes].first[:recorded_output]).to include(source: "none")
  end

  it "distinguishes a node that did not run from one that produced no items", :aggregate_failures do
    execution = record_execution("config-1" => [])
    nodes = invoke_tool(%w[config-1 format-1])[:nodes]

    expect(nodes.first[:recorded_output]).to include(
      source: "execution",
      execution_id: execution.id,
      outputs: [{ total_items: 0, items: [] }],
    )
    expect(nodes.second[:recorded_output]).to include(
      source: "none",
      note: a_string_including("no successful run"),
    )
  end

  it "samples recorded output and marks what it truncated", :aggregate_failures do
    items = Array.new(5) { |index| { "json" => { "index" => index, "body" => "x" * 600 } } }
    record_execution("config-1" => items)

    output = invoke_tool(["config-1"])[:nodes].first[:recorded_output]
    port = output[:outputs].first

    expect(port[:total_items]).to eq(5)
    expect(port[:items].length).to be < 5
    expect(port[:items].first.dig("json", "body")).to end_with("… [truncated, 600 chars total]")
    expect(output[:truncated]).to include("Sample truncated")
  end

  it "prefers pinned data" do
    workflow.update_node_pin_data!("Configuration", [{ "json" => { "pinned" => true } }])

    expect(invoke_tool(["config-1"])[:nodes].first[:recorded_output]).to eq(
      source: "pinned",
      outputs: [{ total_items: 1, items: [{ "json" => { "pinned" => true } }] }],
    )
  end
end
