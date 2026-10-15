# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExecutionProgressPublisher do
  fab!(:workflow, :discourse_workflows_workflow)

  it "publishes compact admin-only updates to list and detail channels" do
    execution = Fabricate(:discourse_workflows_execution, workflow: workflow)
    secret = "private-input-#{SecureRandom.hex(8)}"
    step =
      DiscourseWorkflows::Executor::Step.build(
        node: OpenStruct.new(id: "node-1", name: "Node", type: "action:code", typeVersion: "1.0"),
        position: 0,
        input: [{ "json" => { "secret" => secret } }],
      )

    detail_messages =
      MessageBus.track_publish(described_class.execution_channel(execution.id)) do
        described_class.publish(execution, step: step)
      end

    detail_message = detail_messages.first
    expect(detail_message.group_ids).to eq([Group::AUTO_GROUPS[:admins]])
    expect(detail_message.data).to include(type: "execution_progress", refresh: false)
    expect(detail_message.data[:step]).to include("node_id" => "node-1", "status" => "running")
    expect(detail_message.data.to_json).not_to include(secret)

    step_list_messages =
      MessageBus.track_publish(described_class::EXECUTIONS_CHANNEL) do
        described_class.publish(execution, step: step)
      end
    expect(step_list_messages).to be_empty

    list_messages =
      MessageBus.track_publish(described_class::EXECUTIONS_CHANNEL) do
        described_class.publish(execution)
      end
    expect(list_messages.one?).to eq(true)
    expect(list_messages.first.group_ids).to eq([Group::AUTO_GROUPS[:admins]])
    expect(list_messages.first.data).to include(type: "execution_update")
    expect(list_messages.first.data[:execution]).to include(
      id: execution.id,
      workflow_id: workflow.id,
      status: "pending",
    )
    expect(list_messages.first.data[:execution]).not_to have_key(:workflow_name)
    expect(list_messages.first.data[:execution]).not_to have_key(:trigger_data)

    created_messages =
      MessageBus.track_publish(described_class::EXECUTIONS_CHANNEL) do
        described_class.publish_created(
          execution,
          workflow_name: workflow.name,
          trigger_node: {
            "id" => "trigger-1",
            "name" => "When topic created",
            "type" => "trigger:topic_created",
          },
        )
      end
    expect(created_messages.first.data).to include(type: "execution_created")
    expect(created_messages.first.data[:execution]).to include(
      workflow_name: workflow.name,
      execution_mode: "normal",
      trigger: {
        name: "When topic created",
        type: "trigger:topic_created",
      },
    )
  end

  describe ".subscription_start_id" do
    it "returns the last id when the execution is not running" do
      execution = Fabricate(:discourse_workflows_completed_execution, workflow:)

      expect(described_class.subscription_start_id(execution, 42)).to eq(42)
    end

    it "returns the last id when the execution has stored steps" do
      execution = Fabricate(:discourse_workflows_execution, workflow:, status: :running)
      Fabricate(:discourse_workflows_execution_data_with_steps, execution:)

      expect(described_class.subscription_start_id(execution, 42)).to eq(42)
    end

    it "replays the backlog when a running execution has no stored steps" do
      execution = Fabricate(:discourse_workflows_execution, workflow:, status: :running)

      expect(described_class.subscription_start_id(execution, 42)).to eq(0)
      expect(described_class.subscription_start_id(execution, 250)).to eq(
        250 - described_class::MAX_BACKLOG_SIZE,
      )
    end
  end
end
