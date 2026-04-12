# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Form::V1 do
  describe "#execute" do
    it "returns a form wait request" do
      config = {
        "form_title" => "Page 2",
        "form_fields" => [{ "field_label" => "Email", "field_type" => "text" }],
      }
      action = described_class.new(configuration: config)

      allow(MessageBus).to receive(:publish)

      wait =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: [],
            node_context: {
            },
            resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
            configuration: config,
            property_schema: described_class.property_schema,
            execution_id: 42,
            resume_token: "test-token",
          ),
        )

      expect(wait).to be_a(DiscourseWorkflows::WaitForResume)
      expect(wait.waiting_config["wait_type"]).to eq("form")
      expect(wait.waiting_config["form_title"]).to eq("Page 2")
      expect(wait.waiting_config["form_fields"]).to be_present
    end
  end
end
