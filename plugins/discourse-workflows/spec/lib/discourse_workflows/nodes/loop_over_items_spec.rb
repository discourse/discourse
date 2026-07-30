# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::LoopOverItems::V1 do
  describe "#execute" do
    it "sends first batch to loop output on first execution" do
      items = [
        { "json" => { "id" => 1 } },
        { "json" => { "id" => 2 } },
        { "json" => { "id" => 3 } },
      ]
      node_context = {}

      result =
        execute_node_output(
          configuration: {
            "batch_size" => 2,
          },
          input_items: items,
          node_context: node_context,
        )

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
      expect(result[1][0]["json"]).to include("id" => 1)
      expect(result[1][1]["json"]).to include("id" => 2)
      expect(node_context).to include("current_run_index" => 0)
      expect(node_context["items"].length).to eq(1)
    end

    it "sends next batch on subsequent execution" do
      items = (1..5).map { |id| { "json" => { "id" => id } } }
      node_context = {}

      execute_node_output(
        configuration: {
          "batch_size" => 2,
        },
        input_items: items,
        node_context: node_context,
      )

      loop_back_items = [
        { "json" => { "id" => 1, "processed" => true } },
        { "json" => { "id" => 2, "processed" => true } },
      ]
      result =
        execute_node_output(
          configuration: {
            "batch_size" => 2,
          },
          input_items: loop_back_items,
          node_context: node_context,
        )

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
      expect(result[1][0]["json"]).to include("id" => 3)
      expect(result[1][1]["json"]).to include("id" => 4)
      expect(node_context).to include("current_run_index" => 1)
    end

    it "sends all processed items to done on final execution" do
      items = [
        { "json" => { "id" => 1 } },
        { "json" => { "id" => 2 } },
        { "json" => { "id" => 3 } },
      ]
      node_context = {}

      execute_node_output(
        configuration: {
          "batch_size" => 2,
        },
        input_items: items,
        node_context: node_context,
      )
      execute_node_output(
        configuration: {
          "batch_size" => 2,
        },
        input_items: [
          { "json" => { "id" => 1, "done" => true } },
          { "json" => { "id" => 2, "done" => true } },
        ],
        node_context: node_context,
      )

      result =
        execute_node_output(
          configuration: {
            "batch_size" => 2,
          },
          input_items: [{ "json" => { "id" => 3, "done" => true } }],
          node_context: node_context,
        )

      expect(result[1]).to eq([])
      expect(result[0].length).to eq(3)
      expect(result[0].map { |i| i["json"]["id"] }).to eq([1, 2, 3])
      expect(node_context).to include("done" => true, "no_items_left" => true)
    end

    it "handles batch_size of 1" do
      node_context = {}

      result =
        execute_node_output(
          configuration: {
            "batch_size" => 1,
          },
          input_items: [{ "json" => { "id" => 1 } }, { "json" => { "id" => 2 } }],
          node_context: node_context,
        )
      expect(result[1].length).to eq(1)
      expect(result[1][0]["json"]["id"]).to eq(1)

      result =
        execute_node_output(
          configuration: {
            "batch_size" => 1,
          },
          input_items: [{ "json" => { "id" => 1 } }],
          node_context: node_context,
        )
      expect(result[1].length).to eq(1)
      expect(result[1][0]["json"]["id"]).to eq(2)

      result =
        execute_node_output(
          configuration: {
            "batch_size" => 1,
          },
          input_items: [{ "json" => { "id" => 2 } }],
          node_context: node_context,
        )
      expect(result[1]).to eq([])
      expect(result[0].length).to eq(2)
    end

    it "handles batch_size larger than item count" do
      node_context = {}

      result =
        execute_node_output(
          configuration: {
            "batch_size" => 10,
          },
          input_items: [{ "json" => { "id" => 1 } }, { "json" => { "id" => 2 } }],
          node_context: node_context,
        )

      expect(result[0]).to eq([])
      expect(result[1].length).to eq(2)
    end

    it "handles empty input" do
      node_context = {}

      result =
        execute_node_output(
          configuration: {
            "batch_size" => 1,
          },
          input_items: [],
          node_context: node_context,
        )

      expect(result[1]).to eq([])
      expect(result[0]).to eq([])
    end

    it "defaults batch_size to 1 when invalid" do
      node_context = {}

      result =
        execute_node_output(
          configuration: {
            "batch_size" => 0,
          },
          input_items: [{ "json" => { "id" => 1 } }, { "json" => { "id" => 2 } }],
          node_context: node_context,
        )

      expect(result[1].length).to eq(1)
    end

    it "sets max_run_index correctly" do
      node_context = {}

      execute_node_output(
        configuration: {
          "batch_size" => 3,
        },
        input_items: (1..5).map { |id| { "json" => { "id" => id } } },
        node_context: node_context,
      )

      expect(node_context["max_run_index"]).to eq(2)
    end

    it "resolves batch_size expressions through the execution context" do
      node_context = {}
      items = [
        { "json" => { "id" => 1, "batch_size" => 2 } },
        { "json" => { "id" => 2 } },
        { "json" => { "id" => 3 } },
      ]

      result =
        execute_node_output(
          configuration: {
            "batch_size" => "={{ $json.batch_size }}",
          },
          input_items: items,
          node_context: node_context,
        )

      expect(result[1].map { |item| item["json"]["id"] }).to eq([1, 2])
    end
  end
end
