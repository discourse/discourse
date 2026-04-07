# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  before { SiteSetting.discourse_workflows_enabled = true }

  it "splits items then loops over them in batches" do
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
            "name" => "Set Fields",
            "position" => {
              "x" => 200,
              "y" => 0,
            },
            "position_index" => 1,
            "configuration" => {
              "mode" => "json",
              "include_input" => false,
              "json" => '{"urls": ["a.png", "b.png", "c.png"]}',
            },
          },
          {
            "id" => "split-1",
            "type" => "action:split_out",
            "type_version" => "1.0",
            "name" => "Split Out",
            "position" => {
              "x" => 400,
              "y" => 0,
            },
            "position_index" => 2,
            "configuration" => {
              "field" => "urls",
            },
          },
          {
            "id" => "loop-1",
            "type" => "core:loop_over_items",
            "type_version" => "1.0",
            "name" => "Loop",
            "position" => {
              "x" => 600,
              "y" => 0,
            },
            "position_index" => 3,
            "configuration" => {
              "batch_size" => 2,
            },
          },
          {
            "id" => "code-1",
            "type" => "action:code",
            "type_version" => "1.0",
            "name" => "Code",
            "position" => {
              "x" => 800,
              "y" => 0,
            },
            "position_index" => 4,
            "configuration" => {
              "code" => "({ processed: $json.value })",
            },
          },
          {
            "id" => "done-1",
            "type" => "action:set_fields",
            "type_version" => "1.0",
            "name" => "Done",
            "position" => {
              "x" => 800,
              "y" => 200,
            },
            "position_index" => 5,
            "configuration" => {
              "mode" => "json",
              "include_input" => false,
              "json" => '{"done": true}',
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
            "target_node_id" => "split-1",
            "source_output" => "main",
          },
          {
            "source_node_id" => "split-1",
            "target_node_id" => "loop-1",
            "source_output" => "main",
          },
          { "source_node_id" => "loop-1", "target_node_id" => "code-1", "source_output" => "loop" },
          { "source_node_id" => "code-1", "target_node_id" => "loop-1", "source_output" => "main" },
          { "source_node_id" => "loop-1", "target_node_id" => "done-1", "source_output" => "done" },
        ],
      )

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run

    expect(execution.status).to eq("success")

    split_out_output = execution.execution_data.context_data["Split Out"]
    expect(split_out_output).to be_an(Array)
    expect(split_out_output.length).to eq(3)
    expect(split_out_output.map { |i| i["json"]["value"] }).to eq(%w[a.png b.png c.png])

    done_output = execution.execution_data.context_data["Done"]
    expect(done_output).to be_an(Array)
  end
end
