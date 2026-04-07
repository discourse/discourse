# frozen_string_literal: true

RSpec.describe "Wait for Approval end-to-end" do
  fab!(:user)
  fab!(:approver, :user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.chat_enabled = true
  end

  it "pauses, receives approval via chat interaction, and completes the workflow" do
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
            "id" => "wait-1",
            "type" => "action:chat_approval",
            "type_version" => "1.0",
            "name" => "Approval",
            "position" => {
              "x" => 200,
              "y" => 0,
            },
            "position_index" => 1,
            "configuration" => {
              "message" => "Please review",
              "approve_label" => "LGTM",
              "deny_label" => "Reject",
              "channel_id" => channel.id.to_s,
            },
          },
          {
            "id" => "final-1",
            "type" => "action:set_fields",
            "type_version" => "1.0",
            "name" => "Final",
            "position" => {
              "x" => 400,
              "y" => 0,
            },
            "position_index" => 2,
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
            "target_node_id" => "wait-1",
            "source_output" => "main",
          },
          {
            "source_node_id" => "wait-1",
            "target_node_id" => "final-1",
            "source_output" => "main",
          },
        ],
      )

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", { "topic_id" => 1 }).run
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

    job_args = Jobs::DiscourseWorkflows::ResumeChatApproval.jobs.last&.dig("args", 0)
    Jobs::DiscourseWorkflows::ResumeChatApproval.new.execute(job_args.symbolize_keys) if job_args

    execution.reload
    expect(execution.status).to eq("success")
    expect(execution.execution_data.context_data["Final"].first["json"]).to include(
      "completed" => "true",
      "approved" => true,
    )
  end
end
