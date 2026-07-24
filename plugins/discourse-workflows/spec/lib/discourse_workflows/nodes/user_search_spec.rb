# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserSearch::V1 do
  describe "#valid?" do
    it "returns true when the query is present" do
      trigger = described_class.new("workflow query")

      expect(trigger).to be_valid
    end

    it "returns false when the query is blank" do
      trigger = described_class.new("")

      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns the query", :aggregate_failures do
      trigger = described_class.new("workflow query")
      output = trigger.output

      expect(output).to eq(query: "workflow query")
      expect(output).to match_node_output_schema(described_class)
    end
  end
end
