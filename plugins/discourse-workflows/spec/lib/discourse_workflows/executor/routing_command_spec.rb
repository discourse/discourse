# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::RoutingCommand do
  describe "StoreContext" do
    it "stores name and items" do
      cmd = described_class::StoreContext.new(name: "node_a", items: [{ "json" => { "x" => 1 } }])
      expect(cmd.name).to eq("node_a")
      expect(cmd.items).to eq([{ "json" => { "x" => 1 } }])
    end
  end

  describe "Enqueue" do
    it "stores node and items" do
      node = OpenStruct.new(id: "1", name: "target")
      cmd = described_class::Enqueue.new(node: node, items: [{ "json" => {} }])
      expect(cmd.node).to eq(node)
      expect(cmd.items).to eq([{ "json" => {} }])
    end
  end

  describe "RecordStep" do
    it "stores node_name and step" do
      step = { "node_id" => "1", "status" => "error" }
      cmd = described_class::RecordStep.new(node_name: "test_node", step: step)
      expect(cmd.node_name).to eq("test_node")
      expect(cmd.step).to eq(step)
    end
  end

  describe "Pause" do
    it "stores node, step, and error" do
      node = OpenStruct.new(id: "1")
      step = { "node_id" => "1", "status" => "running" }
      error = DiscourseWorkflows::WaitForWebhook.new
      cmd = described_class::Pause.new(node: node, step: step, error: error)
      expect(cmd.node).to eq(node)
      expect(cmd.step).to eq(step)
      expect(cmd.error).to eq(error)
    end
  end
end
