# frozen_string_literal: true

RSpec.describe "Chat interaction listener for workflow approvals" do # rubocop:disable RSpec/DescribeClass
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:chat_message) { Fabricate(:chat_message, chat_channel: channel) }

  before { SiteSetting.chat_enabled = true }

  it "enqueues ResumeChatApproval when an approve button is clicked" do
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
    action_id = "dwf:#{approve_token}"

    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: Chat::Message.last,
        action: {
          "action_id" => action_id,
          "value" => "approve",
        },
      )

    expect_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeChatApproval,
      args: {
        execution_id: execution.id,
        approved: true,
        action_token: approve_token,
      },
    ) { DiscourseEvent.trigger(:chat_message_interaction, interaction) }
  end

  it "ignores interactions with invalid tokens" do
    action_id = "dwf:invalidtoken1234"

    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: chat_message,
        action: {
          "action_id" => action_id,
        },
      )

    expect { DiscourseEvent.trigger(:chat_message_interaction, interaction) }.not_to change(
      Jobs::DiscourseWorkflows::ResumeChatApproval.jobs,
      :size,
    )
  end

  it "ignores non-workflow interactions" do
    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: chat_message,
        action: {
          "action_id" => "some_other_action",
        },
      )

    expect { DiscourseEvent.trigger(:chat_message_interaction, interaction) }.not_to change(
      Jobs::DiscourseWorkflows::ResumeChatApproval.jobs,
      :size,
    )
  end
end
