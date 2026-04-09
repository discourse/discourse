# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:topic)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
  end

  describe "#run" do
    it "executes a loop workflow: trigger -> loop -> action -> loop-back -> done" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:manual",
              "type_version" => "1.0",
              "name" => "Manual",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "set-fields-1",
              "type" => "action:set_fields",
              "type_version" => "1.0",
              "name" => "Create Items",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
                "mode" => "json",
                "include_input" => false,
                "json" => '{"item_id": "1"}',
              },
            },
            {
              "id" => "loop-1",
              "type" => "core:loop_over_items",
              "type_version" => "1.0",
              "name" => "Loop",
              "position" => {
                "x" => 400,
                "y" => 0,
              },
              "position_index" => 2,
              "configuration" => {
                "batch_size" => 1,
              },
            },
            {
              "id" => "process-1",
              "type" => "action:set_fields",
              "type_version" => "1.0",
              "name" => "Process Item",
              "position" => {
                "x" => 600,
                "y" => 0,
              },
              "position_index" => 3,
              "configuration" => {
                "mode" => "json",
                "include_input" => true,
                "json" => '{"processed": "true"}',
              },
            },
            {
              "id" => "done-1",
              "type" => "action:set_fields",
              "type_version" => "1.0",
              "name" => "Final Step",
              "position" => {
                "x" => 600,
                "y" => 200,
              },
              "position_index" => 4,
              "configuration" => {
                "mode" => "json",
                "include_input" => true,
                "json" => '{"completed": "true"}',
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "set-fields-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "set-fields-1",
              "target_node_id" => "loop-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "loop-1",
              "target_node_id" => "process-1",
              "source_output" => "loop",
            },
            {
              "source_node_id" => "process-1",
              "target_node_id" => "loop-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "loop-1",
              "target_node_id" => "done-1",
              "source_output" => "done",
            },
          ],
        )

      trigger_data = {}
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      final_output = execution.execution_data.context_data["Final Step"]
      expect(final_output).to be_an(Array)
      expect(final_output.first["json"]).to include("processed" => "true", "completed" => "true")
    end

    it "processes multiple items through the loop in batches" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:manual",
              "type_version" => "1.0",
              "name" => "Manual",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "loop-1",
              "type" => "core:loop_over_items",
              "type_version" => "1.0",
              "name" => "Loop",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
                "batch_size" => 1,
              },
            },
            {
              "id" => "process-1",
              "type" => "action:set_fields",
              "type_version" => "1.0",
              "name" => "Process",
              "position" => {
                "x" => 400,
                "y" => 0,
              },
              "position_index" => 2,
              "configuration" => {
                "mode" => "json",
                "include_input" => true,
                "json" => '{"tagged": "yes"}',
              },
            },
            {
              "id" => "done-1",
              "type" => "action:set_fields",
              "type_version" => "1.0",
              "name" => "Done",
              "position" => {
                "x" => 400,
                "y" => 200,
              },
              "position_index" => 3,
              "configuration" => {
                "include_input" => true,
                "fields" => [{ "key" => "final", "value" => "true", "type" => "string" }],
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "loop-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "loop-1",
              "target_node_id" => "process-1",
              "source_output" => "loop",
            },
            {
              "source_node_id" => "process-1",
              "target_node_id" => "loop-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "loop-1",
              "target_node_id" => "done-1",
              "source_output" => "done",
            },
          ],
        )

      trigger_data = { items: [{ name: "a" }, { name: "b" }, { name: "c" }] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      done_output = execution.execution_data.context_data["Done"]
      expect(done_output).to be_an(Array)
      expect(done_output.length).to eq(1)
    end
  end
end
