# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ChatApproval::V1 do
  fab!(:channel, :chat_channel)
  fab!(:execution, :discourse_workflows_execution)

  before { SiteSetting.chat_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:chat_approval")
    end
  end

  describe "#execute" do
    let(:resume_token) { SecureRandom.uuid }
    let(:sandbox) { DiscourseWorkflows::JsSandbox.new({}) }

    after { sandbox.dispose }

    def build_exec_ctx(config)
      resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox)
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: [{ "json" => {} }],
        node_context: {
        },
        resolver: resolver,
        configuration: config,
        property_schema: described_class.property_schema,
        execution_id: execution.id,
        node_id: "node_abc",
        resume_token: resume_token,
      )
    end

    it "sends a chat message and puts the execution to wait" do
      config = {
        "message" => "Please approve this",
        "approve_label" => "Yes",
        "deny_label" => "No",
        "channel_id" => channel.id.to_s,
        "timeout_minutes" => "30",
        "timeout_action" => "fail",
      }
      instance = described_class.new(configuration: config)
      exec_ctx = build_exec_ctx(config)

      freeze_time do
        instance.execute(exec_ctx)

        expect(exec_ctx.waiting?).to be true
        expect(exec_ctx.waiting_until).to eq(30.minutes.from_now)
      end
    end

    it "creates buttons with resume_token-based action IDs" do
      config = {
        "message" => "Please approve this",
        "approve_label" => "Yes",
        "deny_label" => "No",
        "channel_id" => channel.id.to_s,
        "timeout_action" => "fail",
      }
      instance = described_class.new(configuration: config)
      exec_ctx = build_exec_ctx(config)
      instance.execute(exec_ctx)

      message = Chat::Message.last
      buttons = message.blocks.first["elements"]
      expect(buttons.map { |b| b["action_id"] }).to eq(
        ["#{resume_token}:approve", "#{resume_token}:deny"],
      )
    end

    it "uses default labels when none provided" do
      config = {
        "message" => "Approve?",
        "channel_id" => channel.id.to_s,
        "timeout_action" => "deny",
      }
      instance = described_class.new(configuration: config)
      exec_ctx = build_exec_ctx(config)
      instance.execute(exec_ctx)

      expect(exec_ctx.waiting?).to be true
      expect(exec_ctx.waiting_until).to be_nil
    end
  end
end
