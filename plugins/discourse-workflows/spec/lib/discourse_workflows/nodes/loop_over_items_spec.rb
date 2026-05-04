# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::LoopOverItems::V1 do
  def make_items(*values)
    values.map { |v| { "json" => v.deep_stringify_keys } }
  end

  def build_exec_ctx(items, node_context: {})
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: items,
      node_context: node_context,
    )
  end

  describe "#execute" do
    it "sends first batch to loop output on first execution" do
      node = described_class.new(configuration: { "batch_size" => 2 })
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 })
      node_context = {}

      result = node.execute(build_exec_ctx(items, node_context: node_context))

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
      expect(result[1][0]["json"]).to include("id" => 1)
      expect(result[1][1]["json"]).to include("id" => 2)
      expect(node_context).to include("current_run_index" => 0)
      expect(node_context["items"].length).to eq(1)
    end

    it "sends next batch on subsequent execution" do
      node = described_class.new(configuration: { "batch_size" => 2 })
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 })
      node_context = {}

      node.execute(build_exec_ctx(items, node_context: node_context))

      loop_back_items = make_items({ id: 1, processed: true }, { id: 2, processed: true })
      result = node.execute(build_exec_ctx(loop_back_items, node_context: node_context))

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
      expect(result[1][0]["json"]).to include("id" => 3)
      expect(result[1][1]["json"]).to include("id" => 4)
      expect(node_context).to include("current_run_index" => 1)
    end

    it "sends all processed items to done on final execution" do
      node = described_class.new(configuration: { "batch_size" => 2 })
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 })
      node_context = {}

      node.execute(build_exec_ctx(items, node_context: node_context))

      loop_back_1 = make_items({ id: 1, done: true }, { id: 2, done: true })
      node.execute(build_exec_ctx(loop_back_1, node_context: node_context))

      loop_back_2 = make_items({ id: 3, done: true })
      result = node.execute(build_exec_ctx(loop_back_2, node_context: node_context))

      expect(result[1]).to eq([])
      expect(result[0].length).to eq(3)
      expect(result[0].map { |i| i["json"]["id"] }).to eq([1, 2, 3])
      expect(node_context).to include("done" => true, "no_items_left" => true)
    end

    it "handles batch_size of 1" do
      node = described_class.new(configuration: { "batch_size" => 1 })
      items = make_items({ id: 1 }, { id: 2 })
      node_context = {}

      result = node.execute(build_exec_ctx(items, node_context: node_context))
      expect(result[1].length).to eq(1)
      expect(result[1][0]["json"]["id"]).to eq(1)

      result = node.execute(build_exec_ctx(make_items({ id: 1 }), node_context: node_context))
      expect(result[1].length).to eq(1)
      expect(result[1][0]["json"]["id"]).to eq(2)

      result = node.execute(build_exec_ctx(make_items({ id: 2 }), node_context: node_context))
      expect(result[1]).to eq([])
      expect(result[0].length).to eq(2)
    end

    it "handles batch_size larger than item count" do
      node = described_class.new(configuration: { "batch_size" => 10 })
      items = make_items({ id: 1 }, { id: 2 })
      node_context = {}

      result = node.execute(build_exec_ctx(items, node_context: node_context))

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
    end

    it "handles empty input" do
      node = described_class.new(configuration: { "batch_size" => 1 })
      node_context = {}

      result = node.execute(build_exec_ctx([], node_context: node_context))

      expect(result[1]).to eq([])
      expect(result[0]).to eq([])
    end

    it "defaults batch_size to 1 when invalid" do
      node = described_class.new(configuration: { "batch_size" => 0 })
      items = make_items({ id: 1 }, { id: 2 })
      node_context = {}

      result = node.execute(build_exec_ctx(items, node_context: node_context))

      expect(result[1].length).to eq(1)
    end

    it "sets max_run_index correctly" do
      node = described_class.new(configuration: { "batch_size" => 3 })
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 })
      node_context = {}

      node.execute(build_exec_ctx(items, node_context: node_context))

      expect(node_context["max_run_index"]).to eq(2)
    end
  end
end
