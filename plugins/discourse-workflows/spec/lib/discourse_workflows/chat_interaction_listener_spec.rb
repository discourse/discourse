# frozen_string_literal: true

RSpec.describe "Chat interaction listener for workflow approvals" do # rubocop:disable RSpec/DescribeClass
  fab!(:user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.chat_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::ChatApproval::V1)
  end

  after { DiscourseWorkflows::Registry.reset! }

  def build_signed_action_id(execution_id, step_id, decision)
    payload = "#{execution_id}:#{step_id}"
    signature = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, payload)
    "dwf:#{execution_id}:#{step_id}:#{decision}:#{signature}"
  end

  it "enqueues ResumeExecution when an approve button is clicked" do
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
        type: "action:chat_approval",
        name: "Wait",
        position_index: 1,
        configuration: {
          "message" => "Approve?",
          "channel_id" => channel.id.to_s,
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: wait_node,
    )

    execution = DiscourseWorkflows::Executor.new(trigger_node, {}).run
    expect(execution.status).to eq("waiting")

    step = execution.steps.find_by(status: :waiting)
    action_id = build_signed_action_id(execution.id, step.id, "approve")

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
      job: Jobs::DiscourseWorkflows::ResumeExecution,
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
        message: Fabricate(:chat_message, chat_channel: channel),
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
        message: Fabricate(:chat_message, chat_channel: channel),
        action: {
          "action_id" => "some_other_action",
        },
      )

    DiscourseEvent.trigger(:chat_message_interaction, interaction)
  end
end
