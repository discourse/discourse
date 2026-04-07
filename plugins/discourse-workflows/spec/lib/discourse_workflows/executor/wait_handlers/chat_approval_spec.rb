# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::WaitHandlers::ChatApproval do
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }
  fab!(:execution) do
    Fabricate(
      :discourse_workflows_execution,
      workflow: workflow,
      status: :running,
      started_at: Time.current,
    )
  end
  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.chat_enabled = true
  end

  def build_state(execution)
    state =
      instance_double(
        DiscourseWorkflows::Executor::ExecutionState,
        execution: execution,
        waiting_step:
          DiscourseWorkflows::Executor::Step.new(
            node_id: "wait-1",
            node_name: "Wait",
            node_type: "action:chat_approval",
            position: 0,
            input: [],
          ),
        waiting_node:
          DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
            id: "wait-1",
            type: "action:chat_approval",
            type_version: "1.0",
            name: "Wait",
            position: {
              "x" => 0,
              "y" => 0,
            },
            configuration: {
            },
          ),
        waiting_config: {
        },
        context: {
          "__resume_token" => "test-token",
        },
      )
    allow(state).to receive(:save!)
    state
  end

  describe "#pause!" do
    it "stores chat_message_id in waiting_config" do
      state = build_state(execution)
      fake_message = OpenStruct.new(id: 42)
      described_class.stubs(:send_chat_message).returns(fake_message)

      handler = described_class.new(state)
      wait =
        DiscourseWorkflows::WaitForChatApproval.new(
          message_text: "Please approve",
          channel_id: channel.id.to_s,
        )

      handler.pause!(wait)

      execution.reload
      expect(execution.status).to eq("waiting")
      expect(execution.waiting_config).to include("wait_type" => described_class.wait_type)
      expect(execution.waiting_config).to include("chat_message_id" => 42)
      expect(execution.waiting_config).to include("chat_channel_id" => channel.id)
    end

    it "stores timeout config when timeout_minutes is set" do
      state = build_state(execution)
      fake_message = OpenStruct.new(id: 99)
      described_class.stubs(:send_chat_message).returns(fake_message)

      handler = described_class.new(state)
      wait =
        DiscourseWorkflows::WaitForChatApproval.new(
          message_text: "Approve?",
          channel_id: channel.id.to_s,
          timeout_minutes: 60,
          timeout_action: "fail",
        )

      freeze_time do
        handler.pause!(wait)

        execution.reload
        expect(execution.waiting_until).to eq_time(60.minutes.from_now)
        expect(execution.waiting_config).to include(
          "wait_type" => described_class.wait_type,
          "timeout_action" => "fail",
        )
      end
    end

    it "builds HMAC-signed action IDs for approve and deny" do
      state = build_state(execution)

      handler = described_class.new(state)
      wait =
        DiscourseWorkflows::WaitForChatApproval.new(
          message_text: "Approve this",
          channel_id: channel.id.to_s,
          approve_label: "Yes",
          deny_label: "No",
        )

      handler.pause!(wait)

      chat_message = Chat::Message.where(chat_channel_id: channel.id).last
      elements = chat_message.blocks.first["elements"]
      expect(elements.size).to eq(2)
      expect(elements.first["action_id"]).to start_with("dwf:")
      expect(elements.first["text"]["text"]).to eq("Yes")
      expect(elements.second["text"]["text"]).to eq("No")
    end
  end

  describe ".on_timeout" do
    it "resumes with a denied timed-out response" do
      execution =
        instance_double(
          DiscourseWorkflows::Execution,
          waiting_config: {
            "chat_channel_id" => channel.id,
            "timeout_action" => "deny",
          },
        )

      DiscourseWorkflows::Executor.expects(:resume).with(
        execution,
        [{ "json" => { "approved" => false, "channel_id" => channel.id, "timed_out" => true } }],
      )

      described_class.on_timeout(execution)
    end

    it "fails the execution when timeout_action is fail" do
      execution =
        instance_double(
          DiscourseWorkflows::Execution,
          waiting_config: {
            "timeout_action" => "fail",
          },
        )

      execution.expects(:fail_with_timeout!)

      described_class.on_timeout(execution)
    end
  end
end
