# frozen_string_literal: true

RSpec.describe "Chat interaction listener for workflow approvals" do # rubocop:disable RSpec/DescribeClass
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:chat_message) { Fabricate(:chat_message, chat_channel: channel) }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.chat_enabled = true
  end

  def build_signed_action_id(execution_id, node_id, decision)
    payload = "#{execution_id}:#{node_id}:#{decision}"
    signature = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, payload)
    "dwf:#{execution_id}:#{node_id}:#{decision}:#{signature}"
  end

  it "enqueues ResumeChatApproval when an approve button is clicked" do
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
            "name" => "Wait",
            "position" => {
              "x" => 200,
              "y" => 0,
            },
            "position_index" => 1,
            "configuration" => {
              "message" => "Approve?",
              "channel_id" => channel.id.to_s,
            },
          },
        ],
        connections: [
          {
            "source_node_id" => "trigger-1",
            "target_node_id" => "wait-1",
            "source_output" => "main",
          },
        ],
      )

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    expect(execution.status).to eq("waiting")

    action_id = build_signed_action_id(execution.id, "wait-1", "approve")

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
      },
    ) { DiscourseEvent.trigger(:chat_message_interaction, interaction) }
  end

  it "ignores interactions with invalid signatures" do
    action_id = "dwf:999:888:approve:invalidsignature"

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
