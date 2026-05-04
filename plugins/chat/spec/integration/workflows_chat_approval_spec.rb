# frozen_string_literal: true

RSpec.describe "Wait for Approval end-to-end" do
  fab!(:user)
  fab!(:approver, :user)
  fab!(:channel, :chat_channel)

  before { SiteSetting.chat_enabled = true }

  it "pauses, receives approval via chat interaction, and completes the workflow" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "wait-1",
               "action:chat_approval",
               name: "Approval",
               configuration: {
                 "message" => "Please review",
                 "approve_label" => "LGTM",
                 "deny_label" => "Reject",
                 "channel_id" => channel.id.to_s,
               }
        g.node "final-1",
               "action:set_fields",
               name: "Final",
               configuration: {
                 "mode" => "json",
                 "include_input" => true,
                 "json" => '{"completed": "true"}',
               }
        g.chain "trigger-1", "wait-1", "final-1"
      end

    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

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

    job_args = Jobs::Chat::ResumeWorkflowApproval.jobs.last&.dig("args", 0)
    Jobs::Chat::ResumeWorkflowApproval.new.execute(job_args.symbolize_keys) if job_args

    execution.reload
    expect(execution.status).to eq("success")
    expect(execution.execution_data.context_data["Final"].first["json"]).to include(
      "completed" => "true",
      "approved" => true,
    )
  end

  it "rejects a stale approval button when the execution revisits the same approval node" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "wait-1",
               "action:chat_approval",
               name: "Approval",
               configuration: {
                 "message" => "Please review",
                 "channel_id" => channel.id.to_s,
               }
        g.chain "trigger-1", "wait-1"
      end

    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    expect(execution.status).to eq("waiting")

    first_message = Chat::Message.where(chat_channel_id: channel.id).last
    stale_action_id = first_message.blocks.first["elements"].first["action_id"]

    interaction =
      Chat::MessageInteraction.new(
        user: approver,
        message: first_message,
        action: {
          "action_id" => stale_action_id,
          "value" => "approve",
        },
      )
    DiscourseEvent.trigger(:chat_message_interaction, interaction)
    job_args = Jobs::Chat::ResumeWorkflowApproval.jobs.last&.dig("args", 0)
    Jobs::Chat::ResumeWorkflowApproval.new.execute(job_args.symbolize_keys) if job_args

    expect(execution.reload.status).to eq("success")

    execution.update!(status: :waiting, waiting_node_id: "wait-1", resume_token: SecureRandom.uuid)

    stale_interaction =
      Chat::MessageInteraction.new(
        user: approver,
        message: first_message,
        action: {
          "action_id" => stale_action_id,
          "value" => "approve",
        },
      )
    DiscourseEvent.trigger(:chat_message_interaction, stale_interaction)

    stale_job_args = Jobs::Chat::ResumeWorkflowApproval.jobs.last&.dig("args", 0)
    Jobs::Chat::ResumeWorkflowApproval.new.execute(stale_job_args.symbolize_keys) if stale_job_args

    expect(execution.reload.status).to eq("waiting")
  end
end
