# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::MarkdownTable::V1 do
  describe "metadata" do
    it "has the expected identifier and presentation" do
      expect(described_class.identifier).to eq("action:markdown_table")
      expect(described_class.icon).to eq("table-cells")
      expect(described_class.color).to eq("green")
      expect(described_class.group).to eq("data")
    end
  end
end
