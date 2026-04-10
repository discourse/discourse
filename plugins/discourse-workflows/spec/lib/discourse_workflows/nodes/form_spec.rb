# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Form::V1 do
  describe "#execute" do
    it "raises WaitForResume with form type" do
      config = {
        "form_title" => "Page 2",
        "form_fields" => [{ "field_label" => "Email", "field_type" => "text" }],
      }
      action = described_class.new(configuration: config)

      expect {
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: [],
            node_context: {
            },
            resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
            configuration: config,
            configuration_schema: described_class.configuration_schema,
          ),
        )
      }.to raise_error(DiscourseWorkflows::WaitForForm) do |error|
        expect(error.form_title).to eq("Page 2")
        expect(error.form_fields).to be_present
      end
    end
  end
end
