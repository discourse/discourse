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

  it "adds pairedItem to one-to-one action outputs" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "source",
               "action:set_fields",
               name: "Source",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => false,
                 "json_output" => '{"rows": [{"id": 1}, {"id": 2}]}',
               }
        g.node "split", "action:split_out", name: "Split", configuration: { "field" => "rows" }
        g.node "set",
               "action:set_fields",
               name: "Set",
               configuration: {
                 "mode" => "manual",
                 "include_other_fields" => true,
                 "assignments" => {
                   "assignments" => [{ "name" => "seen", "value" => "true", "type" => "boolean" }],
                 },
               }
        g.chain "trigger-1", "source", "split", "set"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Set").map { |item| item["pairedItem"] }).to eq(
      [{ "item" => 0 }, { "item" => 1 }],
    )
  end

  it "keeps original input indexes after filtering items" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "source",
               "action:set_fields",
               name: "Source",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => false,
                 "json_output" => '{"rows": [{"id": 1}, {"id": 2}]}',
               }
        g.node "split", "action:split_out", name: "Split", configuration: { "field" => "rows" }
        g.node "filter",
               "condition:filter",
               name: "Filter",
               configuration: {
                 "conditions" => [
                   {
                     "id" => "1",
                     "leftValue" => "={{ $json.id }}",
                     "rightValue" => 2,
                     "operator" => {
                       "type" => "number",
                       "operation" => "equals",
                     },
                   },
                 ],
                 "combinator" => "and",
               }
        g.chain "trigger-1", "source", "split", "filter"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Filter").map { |item| item["json"]["id"] }).to eq([2, 1])
    expect(context_output(execution, "Filter").first["pairedItem"]).to eq("item" => 1)
  end

  it "resolves previous-node .item through linked lineage" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "source",
               "action:set_fields",
               name: "Source",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => false,
                 "json_output" =>
                   '{"rows": [{"id": 1, "label": "first"}, {"id": 2, "label": "second"}]}',
               }
        g.node "split", "action:split_out", name: "Split", configuration: { "field" => "rows" }
        g.node "filter",
               "condition:filter",
               name: "Filter",
               configuration: {
                 "conditions" => [
                   {
                     "id" => "1",
                     "leftValue" => "={{ $json.id }}",
                     "rightValue" => 2,
                     "operator" => {
                       "type" => "number",
                       "operation" => "equals",
                     },
                   },
                 ],
                 "combinator" => "and",
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
                       "name" => "linked_label",
                       "value" => "={{ $('Split').item.json.label }}",
                       "type" => "string",
                     },
                   ],
                 },
               }
        g.chain "trigger-1", "source", "split", "filter", "set"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Set").first.dig("json", "linked_label")).to eq("second")
  end

  it "resolves previous-node .item through append merge lineage" do
    execution =
      run_workflow do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "source",
               "action:set_fields",
               name: "Source",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => false,
                 "json_output" =>
                   '{"rows": [{"id": 1, "label": "first"}, {"id": 2, "label": "second"}]}',
               }
        g.node "split", "action:split_out", name: "Split", configuration: { "field" => "rows" }
        g.node "filter-1",
               "condition:filter",
               configuration: {
                 "conditions" => [
                   {
                     "id" => "1",
                     "leftValue" => "={{ $json.id }}",
                     "rightValue" => 1,
                     "operator" => {
                       "type" => "number",
                       "operation" => "equals",
                     },
                   },
                 ],
                 "combinator" => "and",
               }
        g.node "filter-2",
               "condition:filter",
               configuration: {
                 "conditions" => [
                   {
                     "id" => "1",
                     "leftValue" => "={{ $json.id }}",
                     "rightValue" => 2,
                     "operator" => {
                       "type" => "number",
                       "operation" => "equals",
                     },
                   },
                 ],
                 "combinator" => "and",
               }
        g.node "merge", "flow:merge", name: "Merge"
        g.node "set",
               "action:set_fields",
               configuration: {
                 "mode" => "manual",
                 "include_other_fields" => false,
                 "assignments" => {
                   "assignments" => [
                     {
                       "name" => "linked_label",
                       "value" => "={{ $('Split').item.json.label }}",
                       "type" => "string",
                     },
                   ],
                 },
               }
        g.chain "trigger-1", "source", "split"
        g.connect "split", "filter-1"
        g.connect "split", "filter-2"
        g.connect "filter-1", "merge", output: "true", input: "input_1"
        g.connect "filter-2", "merge", output: "true", input: "input_2"
        g.chain "merge", "set"
      end

    expect(execution.status).to eq("success")
    expect(context_output(execution, "Set").map { |item| item.dig("json", "linked_label") }).to eq(
      %w[first second],
    )
    expect(context_output(execution, "Merge").map { |item| item["pairedItem"] }).to eq(
      [{ "item" => 0 }, { "input" => 1, "item" => 0 }],
    )
  end
end
