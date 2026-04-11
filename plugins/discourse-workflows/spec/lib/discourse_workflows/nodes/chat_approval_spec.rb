# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ChatApproval::V1 do
  fab!(:channel, :chat_channel)

  before { SiteSetting.chat_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:chat_approval")
    end
  end

  describe "#execute" do
    it "returns a chat approval wait request" do
      config = {
        "message" => "Please approve this",
        "approve_label" => "Yes",
        "deny_label" => "No",
        "channel_id" => channel.id.to_s,
        "timeout_minutes" => "30",
        "timeout_action" => "fail",
      }
      instance = described_class.new(configuration: config)

      wait =
        instance.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: [{ "json" => {} }],
            node_context: {
            },
            resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
            configuration: config,
            configuration_schema: described_class.configuration_schema,
          ),
        )

      expect(wait).to be_a(DiscourseWorkflows::WaitForChatApproval)
      expect(wait.message_text).to eq("Please approve this")
      expect(wait.approve_label).to eq("Yes")
      expect(wait.deny_label).to eq("No")
      expect(wait.channel_id).to eq(channel.id.to_s)
      expect(wait.timeout_minutes).to eq(30)
      expect(wait.timeout_action).to eq("fail")
    end
  end
end
