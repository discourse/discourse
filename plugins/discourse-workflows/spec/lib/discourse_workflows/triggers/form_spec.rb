# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::Form do
  describe ".identifier" do
    it "returns trigger:form" do
      expect(described_class.identifier).to eq("trigger:form")
    end
  end

  describe ".event_name" do
    it "returns nil" do
      expect(described_class.event_name).to be_nil
    end
  end

  describe ".configuration_schema" do
    it "includes form_fields collection" do
      schema = described_class.configuration_schema
      expect(schema[:form_fields][:type]).to eq(:collection)
      expect(schema[:form_fields][:item_schema][:field_type][:options]).to include(
        "text",
        "dropdown",
      )
    end

    it "includes response_mode" do
      schema = described_class.configuration_schema
      expect(schema[:response_mode][:options]).to eq(%w[on_received workflow_finishes])
    end
  end

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
