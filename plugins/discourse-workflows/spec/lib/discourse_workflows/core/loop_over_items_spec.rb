# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Core::LoopOverItems do
  before { SiteSetting.discourse_workflows_enabled = true }

  def make_items(*values)
    values.map { |v| { "json" => v.deep_stringify_keys } }
  end

  describe ".identifier" do
    it "returns core:loop_over_items" do
      expect(described_class.identifier).to eq("core:loop_over_items")
    end
  end

  describe ".outputs" do
    it "returns done and loop" do
      expect(described_class.outputs).to eq(%w[done loop])
    end
  end

  describe "#execute" do
    it "sends first batch to loop output on first execution" do
      node = described_class.new(configuration: { "batch_size" => 2 })
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 })
      node_context = {}

      result = node.execute({}, input_items: items, node_context: node_context)

      expect(result["loop"].length).to eq(2)
      expect(result["loop"][0]["json"]["id"]).to eq(1)
      expect(result["loop"][1]["json"]["id"]).to eq(2)
      expect(result["done"]).to eq([])
      expect(node_context["current_run_index"]).to eq(0)
      expect(node_context["items"].length).to eq(1)
    end

    it "sends next batch on subsequent execution" do
      node = described_class.new(configuration: { "batch_size" => 2 })
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 })
      node_context = {}

      node.execute({}, input_items: items, node_context: node_context)

      loop_back_items = make_items({ id: 1, processed: true }, { id: 2, processed: true })
      result = node.execute({}, input_items: loop_back_items, node_context: node_context)

      expect(result["loop"].length).to eq(2)
      expect(result["loop"][0]["json"]["id"]).to eq(3)
      expect(result["loop"][1]["json"]["id"]).to eq(4)
      expect(result["done"]).to eq([])
      expect(node_context["current_run_index"]).to eq(1)
    end

    it "sends all processed items to done on final execution" do
      node = described_class.new(configuration: { "batch_size" => 2 })
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 })
      node_context = {}

      node.execute({}, input_items: items, node_context: node_context)

      loop_back_1 = make_items({ id: 1, done: true }, { id: 2, done: true })
      node.execute({}, input_items: loop_back_1, node_context: node_context)

      loop_back_2 = make_items({ id: 3, done: true })
      result = node.execute({}, input_items: loop_back_2, node_context: node_context)

      expect(result["loop"]).to eq([])
      expect(result["done"].length).to eq(3)
      expect(result["done"].map { |i| i["json"]["id"] }).to eq([1, 2, 3])
      expect(node_context["done"]).to eq(true)
      expect(node_context["no_items_left"]).to eq(true)
    end

    it "handles batch_size of 1" do
      node = described_class.new(configuration: { "batch_size" => 1 })
      items = make_items({ id: 1 }, { id: 2 })
      node_context = {}

      result = node.execute({}, input_items: items, node_context: node_context)
      expect(result["loop"].length).to eq(1)
      expect(result["loop"][0]["json"]["id"]).to eq(1)

      result = node.execute({}, input_items: make_items({ id: 1 }), node_context: node_context)
      expect(result["loop"].length).to eq(1)
      expect(result["loop"][0]["json"]["id"]).to eq(2)

      result = node.execute({}, input_items: make_items({ id: 2 }), node_context: node_context)
      expect(result["loop"]).to eq([])
      expect(result["done"].length).to eq(2)
    end

    it "handles batch_size larger than item count" do
      node = described_class.new(configuration: { "batch_size" => 10 })
      items = make_items({ id: 1 }, { id: 2 })
      node_context = {}

      result = node.execute({}, input_items: items, node_context: node_context)

      expect(result["loop"].length).to eq(2)
      expect(result["done"]).to eq([])
    end

    it "handles empty input" do
      node = described_class.new(configuration: { "batch_size" => 1 })
      node_context = {}

      result = node.execute({}, input_items: [], node_context: node_context)

      expect(result["loop"]).to eq([])
      expect(result["done"]).to eq([])
    end

    it "defaults batch_size to 1 when invalid" do
      node = described_class.new(configuration: { "batch_size" => 0 })
      items = make_items({ id: 1 }, { id: 2 })
      node_context = {}

      result = node.execute({}, input_items: items, node_context: node_context)

      expect(result["loop"].length).to eq(1)
    end

    it "sets max_run_index correctly" do
      node = described_class.new(configuration: { "batch_size" => 3 })
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 })
      node_context = {}

      node.execute({}, input_items: items, node_context: node_context)

      expect(node_context["max_run_index"]).to eq(2)
    end
  end
end
