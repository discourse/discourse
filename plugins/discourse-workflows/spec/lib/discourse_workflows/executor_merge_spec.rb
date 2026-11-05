# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  def run_workflow(&block)
    graph = build_workflow_graph(&block)
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

    described_class.new(workflow, "trigger-1", {}).run
  end

  def context_output(execution, name)
    execution.execution_data.context_data[name]
  end

  def if_config(expected_kind)
    {
      "combinator" => "and",
      "conditions" => [
        {
          "id" => "1",
          "leftValue" => "={{ $json.kind }}",
          "rightValue" => expected_kind,
          "operator" => {
            "type" => "string",
            "operation" => "equals",
          },
        },
      ],
    }
  end

  def source_node(graph, json)
    graph.node "source",
               "action:set_fields",
               name: "Source",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => false,
                 "json_output" => json,
               }
  end

  def extra_node(graph)
    graph.node "extra",
               "action:set_fields",
               name: "Extra",
               configuration: {
                 "mode" => "manual",
                 "include_other_fields" => false,
                 "assignments" => {
                   "assignments" => [{ "name" => "extra", "value" => "yes", "type" => "string" }],
                 },
               }
  end

  it "combines inputs connected on non-contiguous slots and keeps the slot in pairedItem" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        source_node(g, '{"id": 1}')
        extra_node(g)
        g.node "merge",
               "flow:merge",
               name: "Merge",
               configuration: {
                 "mode" => "combine",
                 "resolve_clash" => "prefer_last",
               }
        g.chain "trigger-1", "source"
        g.connect "source", "extra"
        g.connect "source", "merge", input: "input_1"
        g.connect "extra", "merge", input: "input_3"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Merge")).to eq(
      [
        {
          "json" => {
            "id" => 1,
            "extra" => "yes",
          },
          "pairedItem" => [{ "input" => 0, "item" => 0 }, { "input" => 2, "item" => 0 }],
        },
      ],
    )
  end

  it "resolves previous-node .item through a combine with a slot gap" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        source_node(g, '{"id": 1}')
        extra_node(g)
        g.node "merge",
               "flow:merge",
               name: "Merge",
               configuration: {
                 "mode" => "combine",
                 "resolve_clash" => "prefer_last",
               }
        g.node "set",
               "action:set_fields",
               name: "Set",
               configuration: {
                 "mode" => "manual",
                 "include_other_fields" => false,
                 "assignments" => {
                   "assignments" => [
                     {
                       "name" => "linked_id",
                       "value" => "={{ $('Source').item.json.id }}",
                       "type" => "number",
                     },
                   ],
                 },
               }
        g.chain "trigger-1", "source"
        g.connect "source", "extra"
        g.connect "source", "merge", input: "input_1"
        g.connect "extra", "merge", input: "input_3"
        g.chain "merge", "set"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Set").map { |item| item.dig("json", "linked_id") }).to eq([1])
  end

  it "keeps per-slot lineage when one output feeds two slots" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        source_node(g, '{"id": 1}')
        g.node "merge", "flow:merge", name: "Merge", configuration: { "mode" => "combine" }
        g.chain "trigger-1", "source"
        g.connect "source", "merge", input: "input_1"
        g.connect "source", "merge", input: "input_2"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Merge")).to eq(
      [
        {
          "json" => {
            "id_1" => 1,
            "id_2" => 1,
          },
          "pairedItem" => [{ "input" => 0, "item" => 0 }, { "input" => 1, "item" => 0 }],
        },
      ],
    )
  end

  it "combines only the delivered inputs when an upstream branch stopped" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        source_node(g, '{"id": 1}')
        g.node "filter", "condition:filter", name: "Filter", configuration: if_config("never")
        extra_node(g)
        g.node "merge",
               "flow:merge",
               name: "Merge",
               configuration: {
                 "mode" => "combine",
                 "resolve_clash" => "prefer_last",
               }
        g.chain "trigger-1", "source"
        g.connect "source", "merge", input: "input_1"
        g.chain "source", "filter", "extra"
        g.connect "extra", "merge", input: "input_2"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Merge").map { |item| item["json"] }).to eq([{ "id" => 1 }])
  end

  it "produces no items when a connected input delivered an empty list" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        source_node(g, '{"kind": "a"}')
        g.node "if-a", "condition:if", name: "If A", configuration: if_config("a")
        g.node "if-b", "condition:if", name: "If B", configuration: if_config("b")
        g.node "merge",
               "flow:merge",
               name: "Merge",
               configuration: {
                 "mode" => "combine",
                 "resolve_clash" => "prefer_last",
               }
        g.chain "trigger-1", "source"
        g.connect "source", "if-a"
        g.connect "source", "if-b"
        g.connect "if-a", "merge", output: "true", input: "input_1"
        g.connect "if-b", "merge", output: "true", input: "input_2"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Merge")).to eq([])
  end
end
