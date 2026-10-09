# frozen_string_literal: true

RSpec.describe Jobs::Chat::ResumeWorkflowApprovalInteraction do
  fab!(:workflow_owner, :user)
  fab!(:clicking_user, :user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  it "resumes the waiting V2 execution from the persisted interaction" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        builder.node(
          "wait-1",
          "action:chat_approval",
          name: "Approval",
          configuration: {
            "message" => "Choose",
            "channel_id" => channel.id.to_s,
          },
        )
        builder.chain "trigger-1", "wait-1"
      end
    graph[:nodes].find { |node| node["id"] == "wait-1" }["typeVersion"] = "2.0"
    workflow =
      Fabricate(:discourse_workflows_workflow, created_by: workflow_owner, **graph).tap do |record|
        publish_workflow!(record)
      end
    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    message = Chat::Message.where(chat_channel_id: channel.id).last
    interaction =
      Fabricate(
        :chat_message_interaction,
        user: clicking_user,
        message: message,
        action: message.blocks.first["elements"].first.deep_dup,
      )

    described_class.new.execute(interaction_id: interaction.id)

    expect(execution.reload).to have_attributes(status: "success")
    expect(execution.execution_data.context_data.dig("Approval", 0, "json")).to include(
      "value" => "approve",
      "user" => hash_including("id" => clicking_user.id),
    )
  end

  it "does nothing when the persisted interaction does not exist" do
    expect { described_class.new.execute(interaction_id: -1) }.not_to raise_error
  end
end
