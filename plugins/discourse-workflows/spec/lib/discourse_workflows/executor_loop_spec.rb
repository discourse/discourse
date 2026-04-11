# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:topic)

  before { SiteSetting.tagging_enabled = true }

  describe "#run" do
    it "executes a loop workflow: trigger -> loop -> action -> loop-back -> done" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "set-fields-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "json",
                   "include_input" => false,
                   "json" => '{"item_id": "1"}',
                 }
          g.node "loop-1", "flow:loop_over_items", configuration: { "batch_size" => 1 }
          g.node "process-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "json",
                   "include_input" => true,
                   "json" => '{"processed": "true"}',
                 }
          g.node "done-1",
                 "action:set_fields",
                 name: "Final Step",
                 configuration: {
                   "mode" => "json",
                   "include_input" => true,
                   "json" => '{"completed": "true"}',
                 }
          g.chain "trigger-1", "set-fields-1", "loop-1"
          g.connect "loop-1", "process-1", output: "loop"
          g.chain "process-1", "loop-1"
          g.connect "loop-1", "done-1", output: "done"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

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
                   "mode" => "json",
                   "include_input" => true,
                   "json" => '{"tagged": "yes"}',
                 }
          g.node "done-1",
                 "action:set_fields",
                 name: "Done",
                 configuration: {
                   "include_input" => true,
                   "fields" => [{ "key" => "final", "value" => "true", "type" => "string" }],
                 }
          g.chain "trigger-1", "loop-1"
          g.connect "loop-1", "process-1", output: "loop"
          g.chain "process-1", "loop-1"
          g.connect "loop-1", "done-1", output: "done"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      trigger_data = { items: [{ name: "a" }, { name: "b" }, { name: "c" }] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      done_output = execution.execution_data.context_data["Done"]
      expect(done_output).to be_an(Array)
      expect(done_output.length).to eq(1)
    end
  end
end
