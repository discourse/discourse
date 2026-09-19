# frozen_string_literal: true

RSpec.describe "Chat approval workflows end-to-end" do
  fab!(:workflow_owner, :user)
  fab!(:approver, :user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  def create_approval_workflow(version:, configuration:)
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        builder.node(
          "wait-1",
          "action:chat_approval",
          name: "Approval",
          configuration: configuration,
        )
        builder.node(
          "final-1",
          "action:set_fields",
          name: "Final",
          configuration: {
            "mode" => "raw",
            "include_other_fields" => true,
            "json_output" => '{"completed": true}',
          },
        )
        builder.chain "trigger-1", "wait-1", "final-1"
      end
    graph[:nodes].find { |node| node["id"] == "wait-1" }["typeVersion"] = version

    Fabricate(:discourse_workflows_workflow, created_by: workflow_owner, **graph).tap do |workflow|
      publish_workflow!(workflow)
    end
  end

  def click_approval_button(user:, message:, button:)
    interaction =
      Fabricate(:chat_message_interaction, user: user, message: message, action: button.deep_dup)
    DiscourseEvent.trigger(:chat_message_interaction, interaction)

    action = DiscourseWorkflows::InteractiveResume.action_payload(button["action_id"])["action"]
    job_class =
      if %w[approve deny].include?(action)
        Jobs::Chat::ResumeWorkflowApproval
      else
        Jobs::Chat::ResumeWorkflowApprovalInteraction
      end
    job_args = job_class.jobs.last.fetch("args").first
    job_class.new.execute(job_args.symbolize_keys)
    interaction
  end

  it "uses the default V2 buttons and returns the clicked default value" do
    workflow =
      create_approval_workflow(
        version: "2.0",
        configuration: {
          "message" => "Please review",
          "channel_id" => channel.id.to_s,
        },
      )

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    message = Chat::Message.where(chat_channel_id: channel.id).last
    buttons = message.blocks.first["elements"]

    expect(buttons.map { |button| button.dig("text", "text") }).to eq(%w[Approve Deny])

    click_approval_button(user: approver, message: message, button: buttons.first)

    execution.reload
    expect(execution.status).to eq("success")
    expect(execution.execution_data.context_data.dig("Final", 0, "json")).to include(
      "value" => "approve",
      "user" => hash_including("id" => approver.id, "username" => approver.username),
      "completed" => true,
    )
  end

  it "returns the selected custom V2 value" do
    workflow =
      create_approval_workflow(
        version: "2.0",
        configuration: {
          "message" => "Choose an outcome",
          "buttons" => {
            "values" => [
              { "label" => "Ship it", "value" => "release:now" },
              { "label" => "Revise", "value" => "needs:changes" },
            ],
          },
          "channel_id" => channel.id.to_s,
        },
      )

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    message = Chat::Message.where(chat_channel_id: channel.id).last
    selected_button = message.blocks.first["elements"].last

    click_approval_button(user: approver, message: message, button: selected_button)

    expect(execution.reload.execution_data.context_data.dig("Final", 0, "json")).to include(
      "value" => "needs:changes",
      "channel" => hash_including("id" => channel.id),
    )
  end

  it "supports a V2 workflow with one button" do
    workflow =
      create_approval_workflow(
        version: "2.0",
        configuration: {
          "message" => "Acknowledge",
          "buttons" => {
            "values" => [{ "label" => "Got it", "value" => "acknowledged" }],
          },
          "channel_id" => channel.id.to_s,
        },
      )

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    message = Chat::Message.where(chat_channel_id: channel.id).last
    buttons = message.blocks.first["elements"]

    expect(buttons.one?).to eq(true)
    click_approval_button(user: approver, message: message, button: buttons.first)

    expect(execution.reload.execution_data.context_data.dig("Final", 0, "json")).to include(
      "value" => "acknowledged",
    )
  end

  it "continues a timed-out V2 workflow with its original input and no click fields" do
    workflow =
      create_approval_workflow(
        version: "2.0",
        configuration: {
          "message" => "Please review",
          "channel_id" => channel.id.to_s,
          "timeout_minutes" => "1",
          "timeout_action" => "continue",
        },
      )

    freeze_time
    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", { "request_id" => 42 }).run
    expect(execution).to have_attributes(
      status: "waiting",
      waiting_until: be_within(1.second).of(1.minute.from_now),
      timeout_action: "continue",
    )

    freeze_time(2.minutes.from_now)
    DiscourseWorkflows::Execution::ExpireWaiting.call

    final_output = execution.reload.execution_data.context_data.dig("Final", 0, "json")
    expect(execution.status).to eq("success")
    expect(final_output).to include("request_id" => 42, "completed" => true)
    expect(final_output.keys).not_to include("value", "channel", "user")
  end

  it "fails a timed-out V2 workflow with the approval timeout error" do
    workflow =
      create_approval_workflow(
        version: "2.0",
        configuration: {
          "message" => "Please review",
          "channel_id" => channel.id.to_s,
          "timeout_minutes" => "1",
          "timeout_action" => "fail",
        },
      )

    freeze_time
    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    expect(execution.timeout_action).to eq("fail")

    freeze_time(2.minutes.from_now)
    DiscourseWorkflows::Execution::ExpireWaiting.call

    expect(execution.reload).to have_attributes(
      status: "error",
      error: I18n.t("discourse_workflows.errors.approval_timed_out"),
      timeout_action: nil,
    )
  end

  it "keeps explicit V1 workflows on the legacy output contract" do
    workflow =
      create_approval_workflow(
        version: "1.0",
        configuration: {
          "message" => "Please review",
          "approve_label" => "LGTM",
          "deny_label" => "Reject",
          "channel_id" => channel.id.to_s,
        },
      )

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    message = Chat::Message.where(chat_channel_id: channel.id).last
    approve_button = message.blocks.first["elements"].first

    click_approval_button(user: approver, message: message, button: approve_button)

    expect(execution.reload.execution_data.context_data["Approval"]).to eq(
      [{ "json" => { "approved" => true, "channel_id" => channel.id } }],
    )
    expect(execution.execution_data.context_data.dig("Final", 0, "json")).to eq(
      "approved" => true,
      "channel_id" => channel.id,
      "completed" => true,
    )
  end
end
