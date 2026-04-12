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
    it "sends a chat message and returns a WaitForResume with chat approval config" do
      config = {
        "message" => "Please approve this",
        "approve_label" => "Yes",
        "deny_label" => "No",
        "channel_id" => channel.id.to_s,
        "timeout_minutes" => "30",
        "timeout_action" => "fail",
      }
      instance = described_class.new(configuration: config)

      freeze_time do
        wait =
          instance.execute(
            DiscourseWorkflows::NodeExecutionContext.new(
              input_items: [{ "json" => {} }],
              node_context: {
              },
              resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
              configuration: config,
              property_schema: described_class.property_schema,
              execution_id: execution.id,
              node_id: "node_abc",
            ),
          )

        expect(wait).to be_a(DiscourseWorkflows::WaitForResume)
        expect(wait.waiting_until).to eq(30.minutes.from_now)
        expect(wait.waiting_config["wait_type"]).to eq("chat_approval")
        expect(wait.waiting_config["timeout_action"]).to eq("fail")
        expect(wait.waiting_config["chat_channel_id"]).to eq(channel.id)
        expect(wait.waiting_config["chat_message_id"]).to be_present
        expect(wait.waiting_config["wait_nonce"]).to be_present
        expect(wait.waiting_config["timeout_response_items"]).to eq(
          [{ "json" => { "approved" => false, "channel_id" => channel.id, "timed_out" => true } }],
        )
      end
    end

    it "uses default labels when none provided" do
      config = {
        "message" => "Approve?",
        "channel_id" => channel.id.to_s,
        "timeout_action" => "deny",
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
            property_schema: described_class.property_schema,
            execution_id: execution.id,
            node_id: "node_xyz",
          ),
        )

      expect(wait).to be_a(DiscourseWorkflows::WaitForResume)
      expect(wait.waiting_config["wait_type"]).to eq("chat_approval")
      expect(wait.waiting_config["timeout_action"]).to eq("deny")
      expect(wait.waiting_until).to be_nil
    end
  end
end
