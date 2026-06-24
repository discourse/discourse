# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  before { SiteSetting.tagging_enabled = true }

  describe "#run" do
    it "executes a loop workflow: trigger -> loop -> action -> loop-back -> done" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "set-fields-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"item_id": "1"}',
                 }
          g.node "loop-1", "flow:loop_over_items", configuration: { "batch_size" => 1 }
          g.node "process-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"processed": "true"}',
                 }
          g.node "done-1",
                 "action:set_fields",
                 name: "Final Step",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"completed": "true"}',
                 }
          g.chain "trigger-1", "set-fields-1", "loop-1"
          g.connect "loop-1", "process-1", output: "loop"
          g.chain "process-1", "loop-1"
          g.connect "loop-1", "done-1", output: "done"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = {}
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      final_output = execution.execution_data.context_data["Final Step"]
      expect(final_output).to be_an(Array)
      expect(final_output.first["json"]).to include("processed" => "true", "completed" => "true")
    end

    it "processes multiple items through the loop in batches" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "loop-1", "flow:loop_over_items", configuration: { "batch_size" => 1 }
          g.node "process-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"tagged": "yes"}',
                 }
          g.node "done-1",
                 "action:set_fields",
                 name: "Done",
                 configuration: {
                   "include_other_fields" => true,
                   "assignments" => {
                     "assignments" => [
                       { "name" => "final", "value" => "true", "type" => "string" },
                     ],
                   },
                 }
          g.chain "trigger-1", "loop-1"
          g.connect "loop-1", "process-1", output: "loop"
          g.chain "process-1", "loop-1"
          g.connect "loop-1", "done-1", output: "done"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { items: [{ name: "a" }, { name: "b" }, { name: "c" }] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      done_output = execution.execution_data.context_data["Done"]
      expect(done_output).to be_an(Array)
      expect(done_output.length).to eq(1)
    end

    it "waits for required target inputs before executing a merge node" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "left-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"id": 1, "left": "yes"}',
                 }
          g.node "right-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"topic_id": 1, "right": "yes"}',
                 }
          g.node "merge-1", "flow:merge", name: "Merge branches"
          g.connect "trigger-1", "left-1"
          g.connect "trigger-1", "right-1"
          g.connect "left-1", "merge-1", input: "input_1"
          g.connect "right-1", "merge-1", input: "input_2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run

      expect(execution.status).to eq("success")
      merge_steps =
        execution.execution_data.steps_array.select { |step| step["node_id"] == "merge-1" }
      expect(merge_steps.length).to eq(1)
      expect(merge_steps.first["output"].map { |item| item["json"] }).to contain_exactly(
        include("id" => 1, "left" => "yes"),
        include("topic_id" => 1, "right" => "yes"),
      )
    end

    it "combines two branches into a single item by position" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "left-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"id": 1, "left": "yes"}',
                 }
          g.node "right-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"topic_id": 1, "right": "yes"}',
                 }
          g.node "merge-1",
                 "flow:merge",
                 name: "Merge branches",
                 configuration: {
                   "mode" => "combine",
                   "resolve_clash" => "prefer_last",
                 }
          g.connect "trigger-1", "left-1"
          g.connect "trigger-1", "right-1"
          g.connect "left-1", "merge-1", input: "input_1"
          g.connect "right-1", "merge-1", input: "input_2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run

      expect(execution.status).to eq("success")
      merge_steps =
        execution.execution_data.steps_array.select { |step| step["node_id"] == "merge-1" }
      expect(merge_steps.length).to eq(1)
      expect(merge_steps.first["output"].map { |item| item["json"] }).to eq(
        [{ "id" => 1, "left" => "yes", "topic_id" => 1, "right" => "yes" }],
      )
    end

    it "waits for all incoming branches before executing append merge" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "first-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "first"}',
                 }
          g.node "second-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "second"}',
                 }
          g.node "third-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "third"}',
                 }
          g.node "merge-1", "flow:merge", name: "Append branches"
          g.connect "trigger-1", "first-1"
          g.connect "trigger-1", "second-1"
          g.connect "trigger-1", "third-1"
          g.connect "first-1", "merge-1", input: "input_1"
          g.connect "second-1", "merge-1", input: "input_2"
          g.connect "third-1", "merge-1", input: "input_3"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run

      expect(execution.status).to eq("success")
      merge_steps =
        execution.execution_data.steps_array.select { |step| step["node_id"] == "merge-1" }
      expect(merge_steps.length).to eq(1)
      expect(merge_steps.first["output"].map { |item| item["json"]["source"] }).to contain_exactly(
        "first",
        "second",
        "third",
      )
    end

    it "does not wait for unwired append merge inputs" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "first-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "first"}',
                 }
          g.node "second-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "second"}',
                 }
          g.node "merge-1", "flow:merge", name: "Append branches"
          g.connect "trigger-1", "first-1"
          g.connect "trigger-1", "second-1"
          g.connect "first-1", "merge-1", input: "input_1"
          g.connect "second-1", "merge-1", input: "input_2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run

      expect(execution.status).to eq("success")
      merge_steps =
        execution.execution_data.steps_array.select { |step| step["node_id"] == "merge-1" }
      expect(merge_steps.length).to eq(1)
      expect(merge_steps.first["output"].map { |item| item["json"]["source"] }).to contain_exactly(
        "first",
        "second",
      )
    end

    it "runs append merge with available data when a connected branch does not execute" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "source-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"route": "left"}',
                 }
          g.node "branch-1",
                 "condition:if",
                 configuration: {
                   "conditions" => [
                     {
                       "id" => "1",
                       "leftValue" => "={{ $json.route }}",
                       "rightValue" => "left",
                       "operator" => {
                         "type" => "string",
                         "operation" => "equals",
                       },
                     },
                   ],
                   "combinator" => "and",
                 }
          g.node "left-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"source": "left"}',
                 }
          g.node "right-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"source": "right"}',
                 }
          g.node "merge-1", "flow:merge", name: "Append branches"
          g.chain "trigger-1", "source-1", "branch-1"
          g.connect "branch-1", "left-1", output: "true"
          g.connect "branch-1", "right-1", output: "false"
          g.connect "left-1", "merge-1", input: "input_1"
          g.connect "right-1", "merge-1", input: "input_2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run

      expect(execution.status).to eq("success")
      merge_steps =
        execution.execution_data.steps_array.select { |step| step["node_id"] == "merge-1" }
      expect(merge_steps.length).to eq(1)
      expect(merge_steps.first["output"].map { |item| item["json"]["source"] }).to eq(["left"])
    end

    it "waits for a partial parent merge before flushing a downstream merge" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "direct-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "direct"}',
                 }
          g.node "upstream-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "upstream"}',
                 }
          g.node "never-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "never"}',
                 }
          g.node "merge-a", "flow:merge", name: "Parent merge"
          g.node "merge-b", "flow:merge", name: "Downstream merge"
          g.connect "trigger-1", "upstream-1"
          g.connect "trigger-1", "direct-1"
          g.connect "direct-1", "merge-b", input: "input_1"
          g.connect "upstream-1", "merge-a", input: "input_1"
          g.connect "never-1", "merge-a", input: "input_2"
          g.connect "merge-a", "merge-b", input: "input_2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run

      expect(execution.status).to eq("success")
      merge_steps =
        execution.execution_data.steps_array.select { |step| step["node_id"] == "merge-b" }
      expect(merge_steps.length).to eq(1)
      expect(merge_steps.first["output"].map { |item| item["json"]["source"] }).to eq(
        %w[direct upstream],
      )
    end
  end
end
