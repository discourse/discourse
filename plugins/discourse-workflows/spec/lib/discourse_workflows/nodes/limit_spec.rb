# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Limit::V1 do
  def execute(input_items, configuration = {})
    config = { "max_items" => 10, "keep" => "first" }.merge(configuration)
    execute_node_output(configuration: config, input_items: input_items).first
  end

  def make_indexed_items(count)
    Array.new(count) { |i| { "json" => { "index" => i } } }
  end

  describe "#execute" do
    it "keeps the first N items by default" do
      result = execute(make_indexed_items(5), "max_items" => 3)

      expect(result.length).to eq(3)
      expect(result[0]["json"]["index"]).to eq(0)
      expect(result[1]["json"]["index"]).to eq(1)
      expect(result[2]["json"]["index"]).to eq(2)
    end

    it "keeps the last N items when keep is last" do
      result = execute(make_indexed_items(5), "max_items" => 2, "keep" => "last")

      expect(result.length).to eq(2)
      expect(result[0]["json"]["index"]).to eq(3)
      expect(result[1]["json"]["index"]).to eq(4)
    end

    it "returns all items when max_items exceeds input size" do
      result = execute(make_indexed_items(3), "max_items" => 10)

      expect(result.length).to eq(3)
    end

    it "returns empty array when input is empty" do
      result = execute([], "max_items" => 5)

      expect(result).to eq([])
    end

    it "defaults to 10 items" do
      result = execute(make_indexed_items(15))

      expect(result.length).to eq(10)
    end

    it "handles max_items of 1" do
      result = execute(make_indexed_items(5), "max_items" => 1)

      expect(result.length).to eq(1)
      expect(result[0]["json"]["index"]).to eq(0)
    end

    it "clamps max_items below 1 to 1" do
      result = execute(make_indexed_items(5), "max_items" => 0)

      expect(result.length).to eq(1)
      expect(result[0]["json"]["index"]).to eq(0)
    end

    it "handles max_items of 1 with keep last" do
      result = execute(make_indexed_items(5), "max_items" => 1, "keep" => "last")

      expect(result.length).to eq(1)
      expect(result[0]["json"]["index"]).to eq(4)
    end

    it "resolves max_items expressions through the execution context" do
      items = make_indexed_items(5)
      items.first["json"]["limit"] = 2

      result = execute(items, "max_items" => "={{ $json.limit }}")

      expect(result.map { |item| item["json"]["index"] }).to eq([0, 1])
    end
  end
end
