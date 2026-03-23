# frozen_string_literal: true

RSpec.describe "Wait for Approval end-to-end" do
  fab!(:user)
  fab!(:approver, :user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.chat_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::WaitForApproval::V1)
    DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::IfCondition::V1)
  end

  after { DiscourseWorkflows::Registry.reset! }

  it "pauses, receives approval via chat interaction, and completes the workflow" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:manual",
        name: "Manual",
        position_index: 0,
      )

    wait_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:wait_for_approval",
        name: "Approval",
        position_index: 1,
        configuration: {
          "message" => "Please review",
          "approve_label" => "LGTM",
          "deny_label" => "Reject",
          "channel_id" => channel.id.to_s,
        },
      )

    final_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:set_fields",
        name: "Final",
        position_index: 2,
        configuration: {
          "mode" => "json",
          "include_input" => true,
          "json" => '{"completed": "true"}',
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: wait_node,
    )
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: wait_node,
      target_node: final_node,
    )

    execution = DiscourseWorkflows::Executor.new(trigger_node, { "topic_id" => 1 }).run
    expect(execution.status).to eq("waiting")

    chat_message = Chat::Message.where(chat_channel_id: channel.id).last
    expect(chat_message.message).to eq("Please review")
    buttons = chat_message.blocks.first["elements"]
    expect(buttons.first["text"]["text"]).to eq("LGTM")
    expect(buttons.last["text"]["text"]).to eq("Reject")

    approve_action_id = buttons.first["action_id"]
    interaction =
      Chat::MessageInteraction.new(
        user: approver,
        message: chat_message,
        action: {
          "action_id" => approve_action_id,
          "value" => "approve",
        },
      )

    DiscourseEvent.trigger(:chat_message_interaction, interaction)

    job_args = Jobs::DiscourseWorkflows::ResumeExecution.jobs.last&.dig("args", 0)
    Jobs::DiscourseWorkflows::ResumeExecution.new.execute(job_args.symbolize_keys) if job_args

    execution.reload
    expect(execution.status).to eq("success")
    expect(execution.context["Final"].first["json"]["completed"]).to eq("true")
    expect(execution.context["Final"].first["json"]["approved"]).to eq(true)
  end
end
