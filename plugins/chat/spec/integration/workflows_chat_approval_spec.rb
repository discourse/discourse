# frozen_string_literal: true

RSpec.describe "Wait for Approval end-to-end" do
  fab!(:user)
  fab!(:approver, :user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  def run_pending_approval_job
    job_args = Jobs::Chat::ResumeWorkflowApproval.jobs.last&.dig("args", 0)
    Jobs::Chat::ResumeWorkflowApproval.new.execute(job_args.symbolize_keys) if job_args
  end

  def trigger_approval_interaction(user:, message:, action_id:, value: "approve")
    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: message,
        action: {
          "action_id" => action_id,
          "value" => value,
        },
      )
    DiscourseEvent.trigger(:chat_message_interaction, interaction)
  end

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
                 "timeout_minutes" => "30",
               }
        g.node "final-1",
               "action:set_fields",
               name: "Final",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => true,
                 "json_output" => '{"completed": "true"}',
               }
        g.chain "trigger-1", "wait-1", "final-1"
      end

    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)
    publish_workflow!(workflow)

    execution = nil
    freeze_time do
      execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", { "topic_id" => 1 }).run
      expect(execution.status).to eq("waiting")
      expect(execution.waiting_until).to eq_time(30.minutes.from_now)
    end

    chat_message = Chat::Message.where(chat_channel_id: channel.id).last
    buttons = chat_message.blocks.first["elements"]
    expect(chat_message.message).to eq("Please review")
    expect(buttons.first["text"]["text"]).to eq("LGTM")
    expect(buttons.last["text"]["text"]).to eq("Reject")

    trigger_approval_interaction(
      user: approver,
      message: chat_message,
      action_id: buttons.first["action_id"],
    )
    run_pending_approval_job

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

    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)
    publish_workflow!(workflow)

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    expect(execution.status).to eq("waiting")

    first_message = Chat::Message.where(chat_channel_id: channel.id).last
    original_action_id = first_message.blocks.first["elements"].first["action_id"]

    trigger_approval_interaction(
      user: approver,
      message: first_message,
      action_id: original_action_id,
    )
    run_pending_approval_job
    expect(execution.reload.status).to eq("success")

    execution.update!(status: :waiting, waiting_node_id: "wait-1", resume_token: SecureRandom.uuid)

    trigger_approval_interaction(
      user: approver,
      message: first_message,
      action_id: original_action_id,
    )
    run_pending_approval_job
    expect(execution.reload.status).to eq("waiting")
  end
end
