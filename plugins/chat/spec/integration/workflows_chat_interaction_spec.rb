# frozen_string_literal: true

RSpec.describe "Chat interaction listener for workflow approvals" do
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:chat_message) { Fabricate(:chat_message, chat_channel: channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

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
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)
    publish_workflow!(workflow)

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    expect(execution.status).to eq("waiting")

    approve_action_id = Chat::Message.last.blocks.first["elements"].first["action_id"]

    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: Chat::Message.last,
        action: {
          "action_id" => approve_action_id,
          "value" => "approve",
        },
      )

    expect_enqueued_with(
      job: Jobs::Chat::ResumeWorkflowApproval,
      args: {
        action_id: approve_action_id,
        channel_id: channel.id,
      },
    ) { DiscourseEvent.trigger(:chat_message_interaction, interaction) }
  end

  it "ignores interactions whose action_id does not match any waiting execution" do
    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: chat_message,
        action: {
          "action_id" => "unknown-token:approve",
        },
      )

    expect { DiscourseEvent.trigger(:chat_message_interaction, interaction) }.not_to change(
      Jobs::Chat::ResumeWorkflowApproval.jobs,
      :size,
    )
  end

  it "ignores interactions with an unrecognized action type" do
    action_id =
      DiscourseWorkflows::InteractiveResume.action_id(
        execution_id: 1,
        resume_token: "some-token",
        action: "unknown",
      )

    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: chat_message,
        action: {
          "action_id" => action_id,
        },
      )

    expect { DiscourseEvent.trigger(:chat_message_interaction, interaction) }.not_to change(
      Jobs::Chat::ResumeWorkflowApproval.jobs,
      :size,
    )
  end
end
