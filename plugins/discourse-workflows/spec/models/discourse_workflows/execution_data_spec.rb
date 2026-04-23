# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExecutionData do
  describe "#node_contexts" do
    it "defaults to an empty hash when absent" do
      data = described_class.new(data: { entries: {}, context: {} }.to_json)
      expect(data.node_contexts).to eq({})
    end

    it "returns the node_contexts key from the parsed JSON blob" do
      data =
        described_class.new(
          data: { entries: {}, context: {}, node_contexts: { "node-1" => { "k" => "v" } } }.to_json,
        )
      expect(data.node_contexts).to eq("node-1" => { "k" => "v" })
    end
  end
end
