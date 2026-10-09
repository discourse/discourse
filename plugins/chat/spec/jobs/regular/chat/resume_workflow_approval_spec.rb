# frozen_string_literal: true

RSpec.describe Jobs::Chat::ResumeWorkflowApproval do
  fab!(:workflow_owner, :user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  it "preserves the legacy queued action and channel payload contract" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        builder.node(
          "wait-1",
          "action:chat_approval",
          name: "Approval",
          configuration: {
            "message" => "Approve?",
            "channel_id" => channel.id.to_s,
          },
        )
        builder.chain "trigger-1", "wait-1"
      end
    workflow =
      Fabricate(:discourse_workflows_workflow, created_by: workflow_owner, **graph).tap do |record|
        publish_workflow!(record)
      end
    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    action_id = Chat::Message.last.blocks.first["elements"].first["action_id"]

    described_class.new.execute(action_id: action_id, channel_id: channel.id)

    expect(execution.reload).to have_attributes(status: "success")
    expect(execution.execution_data.context_data["Approval"]).to eq(
      [{ "json" => { "approved" => true, "channel_id" => channel.id } }],
    )
  end
end
