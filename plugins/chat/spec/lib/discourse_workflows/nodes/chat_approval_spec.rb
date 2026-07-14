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

  describe ".load_options_context" do
    fab!(:other_channel) { Fabricate(:chat_channel, name: "Approvals") }
    fab!(:closed_channel) { Fabricate(:chat_channel, name: "Archived", status: :closed) }
    fab!(:dm_channel, :direct_message_channel)

    def load_options(filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "chat_channels",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "returns open public channels with id and name" do
      ids = load_options.map { |option| option[:id] }

      expect(ids).to include(channel.id, other_channel.id)
      expect(ids).not_to include(closed_channel.id, dm_channel.id)
    end

    it "filters channels by the filter term" do
      expect(load_options(filter: "approv")).to contain_exactly(
        { id: other_channel.id, name: other_channel.name },
      )
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
        parameters: config,
        property_schema: described_class.property_schema,
        execution_id: execution.id,
        node_id: "node_abc",
        resume_token: resume_token,
      )
    end

    it "sends a chat message and returns input items" do
      config = {
        "message" => "Please approve this",
        "approve_label" => "Yes",
        "deny_label" => "No",
        "channel_id" => channel.id.to_s,
        "timeout_minutes" => "30",
        "timeout_action" => "fail",
      }
      instance = described_class.new(parameters: config)
      exec_ctx = build_exec_ctx(config)

      result = instance.execute(exec_ctx)

      expect(Chat::Message.last.message).to eq("Please approve this")
      expect(result).to eq([exec_ctx.input_items])
    end

    it "creates buttons with signed action IDs" do
      config = {
        "message" => "Please approve this",
        "approve_label" => "Yes",
        "deny_label" => "No",
        "channel_id" => channel.id.to_s,
        "timeout_action" => "fail",
      }
      instance = described_class.new(parameters: config)
      exec_ctx = build_exec_ctx(config)
      instance.execute(exec_ctx)

      message = Chat::Message.last
      buttons = message.blocks.first["elements"]
      payloads =
        buttons.map do |button|
          DiscourseWorkflows::InteractiveResume.action_payload(button["action_id"])
        end

      expect(payloads).to match(
        [
          hash_including("execution_id" => execution.id, "action" => "approve"),
          hash_including("execution_id" => execution.id, "action" => "deny"),
        ],
      )
      action_ids = buttons.map { |button| button["action_id"] }
      expect(action_ids).to all(satisfy { |id| id.length <= 255 && id.exclude?(resume_token) })
    end

    it "uses default labels when none provided" do
      config = {
        "message" => "Approve?",
        "channel_id" => channel.id.to_s,
        "timeout_action" => "deny",
      }
      instance = described_class.new(parameters: config)
      exec_ctx = build_exec_ctx(config)
      instance.execute(exec_ctx)

      buttons = Chat::Message.last.blocks.first["elements"]
      expect(buttons.first["text"]["text"]).to eq("Approve")
      expect(buttons.last["text"]["text"]).to eq("Deny")
    end

    it "rejects negative timeout values" do
      config = {
        "message" => "Approve?",
        "channel_id" => channel.id.to_s,
        "timeout_minutes" => "-1",
        "timeout_action" => "deny",
      }
      instance = described_class.new(parameters: config)
      exec_ctx = build_exec_ctx(config)

      expect { instance.execute(exec_ctx) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "Timeout minutes must be greater than 0.",
      )
      expect(channel.chat_messages).to be_empty
    end

    it "rejects closed channels outside the selectable channel scope" do
      closed_channel = Fabricate(:chat_channel, name: "Closed", status: :closed)
      config = {
        "message" => "Approve?",
        "channel_id" => closed_channel.id.to_s,
        "timeout_action" => "deny",
      }
      instance = described_class.new(parameters: config)
      exec_ctx = build_exec_ctx(config)

      expect { instance.execute(exec_ctx) }.to raise_error(
        I18n.t(
          "discourse_workflows.errors.chat_approval.channel_not_found",
          channel_id: closed_channel.id,
        ),
      )
      expect(closed_channel.chat_messages).to be_empty
    end

    it "rejects direct message channels outside the selectable channel scope" do
      dm_channel = Fabricate(:direct_message_channel)
      config = {
        "message" => "Approve?",
        "channel_id" => dm_channel.id.to_s,
        "timeout_action" => "deny",
      }
      instance = described_class.new(parameters: config)
      exec_ctx = build_exec_ctx(config)

      expect { instance.execute(exec_ctx) }.to raise_error(
        I18n.t(
          "discourse_workflows.errors.chat_approval.channel_not_found",
          channel_id: dm_channel.id,
        ),
      )
      expect(dm_channel.chat_messages).to be_empty
    end
  end
end
