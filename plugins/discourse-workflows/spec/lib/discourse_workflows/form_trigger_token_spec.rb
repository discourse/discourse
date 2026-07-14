# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::FormTriggerToken do
  let(:workflow_id) { 42 }
  let(:trigger_node_id) { "trigger-1" }
  let(:uuid) { "a1b2c3d4-e5f6-7890-abcd-ef0123456789" }

  describe ".generate" do
    it "encrypts query parameters embedded in public form tokens" do
      token =
        described_class.generate(
          workflow_id: workflow_id,
          trigger_node_id: trigger_node_id,
          uuid: uuid,
          form_query_parameters: {
            tracking_id: "query-hidden-value",
          },
        )

      expect(token).not_to include("query-hidden-value")
      expect(
        described_class.payload(
          token,
          workflow_id: workflow_id,
          trigger_node_id: trigger_node_id,
          uuid: uuid,
        ),
      ).to include("form_query_parameters" => { "tracking_id" => "query-hidden-value" })
    end

    it "treats expired tokens as invalid" do
      token = nil

      freeze_time do
        token =
          described_class.generate(
            workflow_id: workflow_id,
            trigger_node_id: trigger_node_id,
            uuid: uuid,
          )
      end

      freeze_time 2.hours.from_now

      expect(
        described_class.valid?(
          token,
          workflow_id: workflow_id,
          trigger_node_id: trigger_node_id,
          uuid: uuid,
        ),
      ).to be(false)
    end
  end
end
