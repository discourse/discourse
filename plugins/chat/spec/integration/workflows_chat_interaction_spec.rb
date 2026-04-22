# frozen_string_literal: true

RSpec.describe "Chat interaction listener for workflow approvals" do
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:chat_message) { Fabricate(:chat_message, chat_channel: channel) }

  before { SiteSetting.chat_enabled = true }

  it "enqueues ResumeWorkflowApproval when an approve button is clicked" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "wait-1",
               "action:chat_approval",
               configuration: {
                 "message" => "Approve?",
                 "channel_id" => channel.id.to_s,
               }
        g.chain "trigger-1", "wait-1"
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    expect(execution.status).to eq("waiting")

    approve_token = execution.waiting_config["approve_token"]

    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: Chat::Message.last,
        action: {
          "action_id" => approve_token,
          "value" => "approve",
        },
      )

    expect_enqueued_with(
      job: Jobs::Chat::ResumeWorkflowApproval,
      args: {
        execution_id: execution.id,
        approved: true,
        action_token: approve_token,
      },
    ) { DiscourseEvent.trigger(:chat_message_interaction, interaction) }
  end

  it "ignores interactions whose action_id does not match any waiting execution" do
    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: chat_message,
        action: {
          "action_id" => "unknown_action_id",
        },
      )

    expect { DiscourseEvent.trigger(:chat_message_interaction, interaction) }.not_to change(
      Jobs::Chat::ResumeWorkflowApproval.jobs,
      :size,
    )
  end
end
