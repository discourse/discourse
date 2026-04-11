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
  before { SiteSetting.chat_enabled = true }

  describe "#pause!" do
    it "stores chat_message_id in waiting_config" do
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "action:chat_approval",
          context: {
            "__resume_token" => "test-token",
          },
        )
      fake_message = OpenStruct.new(id: 42)
      described_class.stubs(:send_chat_message).returns(fake_message)

      handler = described_class.new(**dependencies)
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
      expect(execution.waiting_config["wait_nonce"]).to be_present
    end

    it "stores timeout config when timeout_minutes is set" do
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "action:chat_approval",
          context: {
            "__resume_token" => "test-token",
          },
        )
      fake_message = OpenStruct.new(id: 99)
      described_class.stubs(:send_chat_message).returns(fake_message)

      handler = described_class.new(**dependencies)
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
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "action:chat_approval",
          context: {
            "__resume_token" => "test-token",
          },
        )

      handler = described_class.new(**dependencies)
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

    it "generates unique nonces across successive waits on the same node" do
      nonces = []

      2.times do
        dependencies =
          build_wait_dependencies(
            execution,
            node_type: "action:chat_approval",
            context: {
              "__resume_token" => "test-token",
            },
          )
        fake_message = OpenStruct.new(id: rand(1000))
        described_class.stubs(:send_chat_message).returns(fake_message)

        handler = described_class.new(**dependencies)
        wait =
          DiscourseWorkflows::WaitForChatApproval.new(
            message_text: "Approve",
            channel_id: channel.id.to_s,
          )

        handler.pause!(wait)
        nonces << execution.reload.waiting_config["wait_nonce"]

        execution.update!(status: :running, waiting_config: {}, waiting_node_id: nil)
      end

      expect(nonces.uniq.size).to eq(2)
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
