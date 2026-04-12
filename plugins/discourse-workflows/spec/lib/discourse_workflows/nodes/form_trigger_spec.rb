# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::FormTrigger::V1 do
  describe "#output" do
    it "returns form data and timestamp" do
      trigger =
        described_class.new(form_data: { name: "Test" }, submitted_at: "2026-01-01T00:00:00Z")
      expect(trigger.output).to eq(
        form_data: {
          name: "Test",
        },
        submitted_at: "2026-01-01T00:00:00Z",
      )
    end
  end
end
