# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  before do
    SiteSetting.discourse_workflows_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SplitOut)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::Code)
    DiscourseWorkflows::Registry.register_core(DiscourseWorkflows::Core::LoopOverItems)
  end

  after { DiscourseWorkflows::Registry.reset! }

  it "splits items then loops over them in batches" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:manual",
        name: "Manual",
        position_index: 0,
      )

    set_fields_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:set_fields",
        name: "Set Fields",
        position_index: 1,
        configuration: {
          "mode" => "json",
          "include_input" => false,
          "json" => '{"urls": ["a.png", "b.png", "c.png"]}',
        },
      )

    split_out_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:split_out",
        name: "Split Out",
        position_index: 2,
        configuration: {
          "field" => "urls",
        },
      )

    loop_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "core:loop_over_items",
        name: "Loop",
        position_index: 3,
        configuration: {
          "batch_size" => 2,
        },
      )

    code_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:code",
        name: "Code",
        position_index: 4,
        configuration: {
          "code" => "({ processed: $json.value })",
        },
      )

    done_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:set_fields",
        name: "Done",
        position_index: 5,
        configuration: {
          "mode" => "json",
          "include_input" => false,
          "json" => '{"done": true}',
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: set_fields_node,
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: set_fields_node,
      target_node: split_out_node,
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: split_out_node,
      target_node: loop_node,
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: loop_node,
      target_node: code_node,
      source_output: "loop",
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: code_node,
      target_node: loop_node,
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: loop_node,
      target_node: done_node,
      source_output: "done",
    )

    execution = DiscourseWorkflows::Executor.new(trigger_node, {}).run

    expect(execution.status).to eq("success")

    split_out_output = execution.context["Split Out"]
    expect(split_out_output).to be_an(Array)
    expect(split_out_output.length).to eq(3)
    expect(split_out_output.map { |i| i["json"]["value"] }).to eq(%w[a.png b.png c.png])

    done_output = execution.context["Done"]
    expect(done_output).to be_an(Array)
  end
end
