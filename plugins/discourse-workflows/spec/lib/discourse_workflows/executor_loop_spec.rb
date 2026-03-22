# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:topic)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields)
    DiscourseWorkflows::Registry.register_core(DiscourseWorkflows::Core::LoopOverItems)
  end

  after { DiscourseWorkflows::Registry.reset! }

  it "executes a loop workflow: trigger -> loop -> action -> loop-back -> done" do
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
        name: "Create Items",
        position_index: 1,
        configuration: {
          "mode" => "json",
          "include_input" => false,
          "json" => '{"item_id": "1"}',
        },
      )

    loop_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "core:loop_over_items",
        name: "Loop",
        position_index: 2,
        configuration: {
          "batch_size" => 1,
        },
      )

    loop_body_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:set_fields",
        name: "Process Item",
        position_index: 3,
        configuration: {
          "mode" => "json",
          "include_input" => true,
          "json" => '{"processed": "true"}',
        },
      )

    done_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:set_fields",
        name: "Final Step",
        position_index: 4,
        configuration: {
          "mode" => "json",
          "include_input" => true,
          "json" => '{"completed": "true"}',
        },
      )

    # trigger -> set_fields (create items)
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: set_fields_node,
    )

    # set_fields -> loop
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: set_fields_node,
      target_node: loop_node,
    )

    # loop --loop--> loop_body
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: loop_node,
      target_node: loop_body_node,
      source_output: "loop",
    )

    # loop_body --main--> loop (loop-back)
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: loop_body_node,
      target_node: loop_node,
    )

    # loop --done--> done_node
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: loop_node,
      target_node: done_node,
      source_output: "done",
    )

    trigger_data = {}
    execution = DiscourseWorkflows::Executor.new(trigger_node, trigger_data).run

    expect(execution.status).to eq("success")

    final_output = execution.context["Final Step"]
    expect(final_output).to be_an(Array)
    expect(final_output.first["json"]["processed"]).to eq("true")
    expect(final_output.first["json"]["completed"]).to eq("true")
  end

  it "processes multiple items through the loop in batches" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:manual",
        name: "Manual",
        position_index: 0,
      )

    loop_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "core:loop_over_items",
        name: "Loop",
        position_index: 1,
        configuration: {
          "batch_size" => 1,
        },
      )

    loop_body_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:set_fields",
        name: "Process",
        position_index: 2,
        configuration: {
          "mode" => "json",
          "include_input" => true,
          "json" => '{"tagged": "yes"}',
        },
      )

    done_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:set_fields",
        name: "Done",
        position_index: 3,
        configuration: {
          "include_input" => true,
          "fields" => [{ "key" => "final", "value" => "true", "type" => "string" }],
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: loop_node,
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: loop_node,
      target_node: loop_body_node,
      source_output: "loop",
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: loop_body_node,
      target_node: loop_node,
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: loop_node,
      target_node: done_node,
      source_output: "done",
    )

    trigger_data = { items: [{ name: "a" }, { name: "b" }, { name: "c" }] }
    execution = DiscourseWorkflows::Executor.new(trigger_node, trigger_data).run

    expect(execution.status).to eq("success")

    done_output = execution.context["Done"]
    expect(done_output).to be_an(Array)
    expect(done_output.length).to eq(1)
  end
end
