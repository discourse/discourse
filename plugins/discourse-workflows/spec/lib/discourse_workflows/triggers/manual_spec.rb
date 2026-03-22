# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::Manual do
  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:manual")
    end
  end

  describe ".event_name" do
    it "returns nil" do
      expect(described_class.event_name).to be_nil
    end
  end

  describe ".output_schema" do
    it "returns an empty hash" do
      expect(described_class.output_schema).to eq({})
    end
  end

  describe "#output" do
    it "returns an empty hash" do
      trigger = described_class.new
      expect(trigger.output).to eq({})
    end
  end
end
