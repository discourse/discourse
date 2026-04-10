# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Manual::V1 do
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
