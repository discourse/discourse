# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::WaitForApproval::V1 do
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.chat_enabled = true
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:wait_for_approval")
    end
  end

  describe "#execute" do
    it "raises WaitForHuman with channel config" do
      instance =
        described_class.new(
          configuration: {
            "message" => "Please approve this",
            "approve_label" => "Yes",
            "deny_label" => "No",
            "channel_id" => channel.id.to_s,
            "timeout_minutes" => "30",
            "timeout_action" => "fail",
          },
        )

      expect {
        instance.execute({}, input_items: [{ "json" => {} }], node_context: {})
      }.to raise_error(DiscourseWorkflows::WaitForHuman) do |error|
        expect(error.message_text).to eq("Please approve this")
        expect(error.approve_label).to eq("Yes")
        expect(error.deny_label).to eq("No")
        expect(error.channel_id).to eq(channel.id.to_s)
        expect(error.timeout_minutes).to eq(30)
        expect(error.timeout_action).to eq("fail")
      end
    end
  end
end
