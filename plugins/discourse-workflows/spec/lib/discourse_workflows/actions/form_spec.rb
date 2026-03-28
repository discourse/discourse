# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::Form::V1 do
  describe ".identifier" do
    it "returns action:form" do
      expect(described_class.identifier).to eq("action:form")
    end
  end

  describe "#execute" do
    it "raises WaitForResume with form type" do
      action =
        described_class.new(
          configuration: {
            "form_title" => "Page 2",
            "form_fields" => [{ "field_label" => "Email", "field_type" => "text" }],
          },
        )

      expect { action.execute({}, input_items: [], node_context: {}) }.to raise_error(
        DiscourseWorkflows::WaitForResume,
      ) do |error|
        expect(error.type).to eq(:form)
        expect(error.form_title).to eq("Page 2")
        expect(error.form_fields).to be_present
      end
    end
  end
end
