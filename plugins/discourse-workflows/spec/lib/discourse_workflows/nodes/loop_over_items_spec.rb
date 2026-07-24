# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::LoopOverItems::V1 do
  def make_items(*values)
    values.map { |v| { "json" => v.deep_stringify_keys } }
  end

  def run_loop(items, node_context:, batch_size:)
    execute_node_output(
      configuration: {
        "batch_size" => batch_size,
      },
      input_items: items,
      node_context: node_context,
    )
  end

  describe "#execute" do
    it "sends first batch to loop output on first execution" do
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 })
      node_context = {}

      result = run_loop(items, node_context: node_context, batch_size: 2)

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
      expect(result[1][0]["json"]).to include("id" => 1)
      expect(result[1][1]["json"]).to include("id" => 2)
      expect(node_context).to include("current_run_index" => 0)
      expect(node_context["items"].length).to eq(1)
    end

    it "sends next batch on subsequent execution" do
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 })
      node_context = {}

      run_loop(items, node_context: node_context, batch_size: 2)

      loop_back_items = make_items({ id: 1, processed: true }, { id: 2, processed: true })
      result = run_loop(loop_back_items, node_context: node_context, batch_size: 2)

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
      expect(result[1][0]["json"]).to include("id" => 3)
      expect(result[1][1]["json"]).to include("id" => 4)
      expect(node_context).to include("current_run_index" => 1)
    end

    it "sends all processed items to done on final execution" do
      items = make_items({ id: 1 }, { id: 2 }, { id: 3 })
      node_context = {}

      run_loop(items, node_context: node_context, batch_size: 2)
      run_loop(
        make_items({ id: 1, done: true }, { id: 2, done: true }),
        node_context: node_context,
        batch_size: 2,
      )

      result =
        run_loop(make_items({ id: 3, done: true }), node_context: node_context, batch_size: 2)

      expect(result[1]).to eq([])
      expect(result[0].length).to eq(3)
      expect(result[0].map { |i| i["json"]["id"] }).to eq([1, 2, 3])
      expect(node_context).to include("done" => true, "no_items_left" => true)
    end

    it "handles batch_size of 1" do
      node_context = {}

      result = run_loop(make_items({ id: 1 }, { id: 2 }), node_context: node_context, batch_size: 1)
      expect(result[1].length).to eq(1)
      expect(result[1][0]["json"]["id"]).to eq(1)

      result = run_loop(make_items({ id: 1 }), node_context: node_context, batch_size: 1)
      expect(result[1].length).to eq(1)
      expect(result[1][0]["json"]["id"]).to eq(2)

      result = run_loop(make_items({ id: 2 }), node_context: node_context, batch_size: 1)
      expect(result[1]).to eq([])
      expect(result[0].length).to eq(2)
    end

    it "handles batch_size larger than item count" do
      node_context = {}

      result =
        run_loop(make_items({ id: 1 }, { id: 2 }), node_context: node_context, batch_size: 10)

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
    end

    it "handles empty input" do
      node_context = {}

      result = run_loop([], node_context: node_context, batch_size: 1)

      expect(result[1]).to eq([])
      expect(result[0]).to eq([])
    end

    it "defaults batch_size to 1 when invalid" do
      node_context = {}

      result = run_loop(make_items({ id: 1 }, { id: 2 }), node_context: node_context, batch_size: 0)

      expect(result[1].length).to eq(1)
    end

    it "sets max_run_index correctly" do
      node_context = {}

      run_loop(
        make_items({ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 }),
        node_context: node_context,
        batch_size: 3,
      )

      expect(node_context["max_run_index"]).to eq(2)
    end

    it "resolves batch_size expressions through the execution context" do
      node_context = {}
      items = make_items({ id: 1, batch_size: 2 }, { id: 2 }, { id: 3 })

      result = run_loop(items, node_context: node_context, batch_size: "={{ $json.batch_size }}")

      expect(result[1].map { |item| item["json"]["id"] }).to eq([1, 2])
    end
  end
end
