# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowValidateScript do
  fab!(:admin)

  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual", name: "Run sample"
        g.node "config", "action:code", name: "Configuration"
        g.chain "trigger-1", "config"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end

  let(:config_code) { <<~JS }
      var config = $("Configuration").first().json;
      if (!config.heading) { throw new Error("Configuration is required"); }
      return [{ json: { title: config.heading } }];
    JS

  def invoke_tool(parameters)
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    described_class.new(
      parameters,
      bot_user: Discourse.system_user,
      llm: nil,
      context: context,
    ).invoke
  end

  def record_configuration_run(json)
    execution = Fabricate(:discourse_workflows_execution, workflow: workflow, status: :success)
    Fabricate(
      :discourse_workflows_execution_data,
      execution: execution,
      data: {
        "entries" => {
        },
        "context" => {
        },
        "node_contexts" => {
        },
        "run_data" => {
          "Configuration" => [
            {
              "node_id" => "config",
              "node_name" => "Configuration",
              "node_type" => "action:code",
              "status" => "success",
              "run_index" => 0,
              "inputs" => [],
              "outputs" => [{ "index" => 0, "items" => [{ "json" => json }], "item_count" => 1 }],
            },
          ],
        },
      },
    )
  end

  it "runs a script against supplied input items and returns output and logs",
     :aggregate_failures do
    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code:
          "console.log('count', $input.all().length); var items = $input.all(); items[0].json.added = true; return items;",
        input_items: [{ "json" => { "id" => 1 } }],
      )

    expect(result).to include(
      valid: true,
      errors: [],
      output: {
        total_items: 1,
        items: [{ "json" => { "id" => 1, "added" => true } }],
      },
    )
    expect(result[:logs]).to contain_exactly(include("message" => "count 1"))
  end

  it "resolves other nodes from the last successful execution" do
    record_configuration_run({ "heading" => "Recorded" })

    result = invoke_tool(mode: "runOnceForAllItems", code: config_code, workflow_id: workflow.id)

    expect(result).to include(
      valid: true,
      output: {
        total_items: 1,
        items: [{ "json" => { "title" => "Recorded" } }],
      },
    )
  end

  it "uses the recorded output of input_node as $input" do
    record_configuration_run({ "heading" => "Recorded" })

    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: "return [{ json: { heading: $input.first().json.heading } }];",
        workflow_id: workflow.id,
        input_node: "Configuration",
      )

    expect(result.dig(:output, :items)).to eq([{ "json" => { "heading" => "Recorded" } }])
  end

  it "uses the requested output of input_node" do
    record_configuration_run({ "heading" => "First" })
    run_data = workflow.last_successful_execution.execution_data
    run = run_data.data.dig("run_data", "Configuration", 0)
    run["outputs"] << {
      "index" => 1,
      "items" => [{ "json" => { "heading" => "Second" } }],
      "item_count" => 1,
    }
    run_data.save!

    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: "return [{ json: { heading: $input.first().json.heading } }];",
        workflow_id: workflow.id,
        input_node: "Configuration",
        input_output_index: 1,
      )

    expect(result.dig(:output, :items)).to eq([{ "json" => { "heading" => "Second" } }])
  end

  it "lets input_items replace an input_node without recorded output" do
    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: "return [{ json: { count: $input.all().length } }];",
        workflow_id: workflow.id,
        input_node: "Configuration",
        input_items: [],
      )

    expect(result.dig(:output, :items)).to eq([{ "json" => { "count" => 0 } }])
  end

  it "rejects node_outputs that are not keyed by node name" do
    result = invoke_tool(mode: "runOnceForAllItems", code: "return [];", node_outputs: [])

    expect(result[:error]).to eq("node_outputs must be an object keyed by node name.")
  end

  it "reports an input_node without recorded output" do
    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: "return [];",
        workflow_id: workflow.id,
        input_node: "Configuration",
      )

    expect(result[:error]).to include("No recorded output")
  end

  it "runs with empty input when input_items is empty" do
    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: "return [{ json: { count: $input.all().length } }];",
        input_items: [],
      )

    expect(result.dig(:output, :items)).to eq([{ "json" => { "count" => 0 } }])
  end

  it "marks truncated logs" do
    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: "for (var i = 0; i < 30; i++) { console.log('line ' + i); } return [];",
      )

    expect(result[:logs].length).to eq(described_class::MAX_LOG_ENTRIES)
    expect(result[:truncated]).to include("Only the first 20 of 30 log entries are shown.")
  end

  it "marks truncated input and output" do
    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: "return $input.all();",
        input_items: Array.new(30) { |index| { "json" => { "index" => index } } },
      )

    expect(result[:output]).to include(total_items: 20)
    expect(result[:output][:items].length).to eq(described_class::MAX_OUTPUT_ITEMS)
    expect(result[:truncated]).to include(
      "Only the first 20 of 30 input_items were used.",
      "Sample truncated",
    )
  end

  it "lets supplied node outputs replace recorded data" do
    record_configuration_run({ "heading" => "Recorded" })

    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: config_code,
        workflow_id: workflow.id,
        node_outputs: {
          "Configuration" => [{ "json" => {} }],
        },
      )

    expect(result).to include(valid: false, errors: [include("Configuration is required")])
  end

  it "reports syntax errors without running the script" do
    result = invoke_tool(mode: "runOnceForAllItems", code: "return [{ json: {} ];")

    expect(result).to include(valid: false, errors: [start_with("JavaScript syntax error")])
  end

  it "rejects all-items access in per-item mode" do
    result =
      invoke_tool(
        mode: "runOnceForEachItem",
        code: "var items = $input.all(); return { json: { count: items.length } };",
      )

    expect(result).to include(
      valid: false,
      errors: ["$input.all is only available in runOnceForAllItems mode"],
    )
  end

  it "accepts code referencing $workflow_vars" do
    result =
      invoke_tool(
        mode: "runOnceForAllItems",
        code: "return [{ json: { priority: $workflow_vars.priority } }];",
      )

    expect(result).to include(valid: true, errors: [])
  end

  it "accepts code referencing $vars" do
    result =
      invoke_tool(mode: "runOnceForAllItems", code: "return [{ json: { region: $vars.region } }];")

    expect(result).to include(valid: true, errors: [])
  end

  it "reports output the Code node rejects" do
    result = invoke_tool(mode: "runOnceForAllItems", code: "return 5;")

    expect(result).to include(valid: false, errors: [include("Code doesn't return items properly")])
  end
end
