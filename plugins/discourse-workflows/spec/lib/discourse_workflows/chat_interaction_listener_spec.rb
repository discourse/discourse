# frozen_string_literal: true

RSpec.describe "Chat interaction listener for workflow approvals" do # rubocop:disable RSpec/DescribeClass
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:chat_message) { Fabricate(:chat_message, chat_channel: channel) }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.chat_enabled = true
  end

  def build_signed_action_id(execution_id, node_id, decision, wait_nonce)
    payload = "#{execution_id}:#{node_id}:#{decision}:#{wait_nonce}"
    signature = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, payload)
    "dwf:#{execution_id}:#{node_id}:#{decision}:#{wait_nonce}:#{signature}"
  end

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

    wait_nonce = execution.waiting_config["wait_nonce"]
    action_id = build_signed_action_id(execution.id, "wait-1", "approve", wait_nonce)

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
        wait_nonce: wait_nonce,
      },
    ) { DiscourseEvent.trigger(:chat_message_interaction, interaction) }
  end

  it "ignores interactions with invalid signatures" do
    action_id = "dwf:999:888:approve:fakenonce:invalidsignature"

    interaction =
      Chat::MessageInteraction.new(
        user: user,
        message: chat_message,
        action: {
          "action_id" => action_id,
        },
      )

    DiscourseEvent.trigger(:chat_message_interaction, interaction)
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

    DiscourseEvent.trigger(:chat_message_interaction, interaction)
  end
end
