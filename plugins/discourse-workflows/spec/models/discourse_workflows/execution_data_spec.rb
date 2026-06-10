# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExecutionData do
  describe "#data" do
    it "defaults to empty execution data" do
      first_data = described_class.new
      second_data = described_class.new

      first_data.data["entries"]["node-1"] = []

      expect(second_data.data).to eq(
        "entries" => {
        },
        "context" => {
        },
        "node_contexts" => {
        },
        "run_data" => {
        },
      )
    end
  end

  describe "#node_contexts" do
    it "defaults to an empty hash when absent" do
      data = described_class.new(data: { "entries" => {}, "context" => {} })
      expect(data.node_contexts).to eq({})
    end

    it "returns the node_contexts key from the stored hash" do
      data = described_class.new(data: { "node_contexts" => { "node-1" => { "k" => "v" } } })
      expect(data.node_contexts).to eq("node-1" => { "k" => "v" })
    end
  end
end
