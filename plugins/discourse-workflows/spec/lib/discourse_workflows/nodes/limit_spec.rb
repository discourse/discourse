# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Limit::V1 do
  def execute(input_items, configuration = {})
    config = { "max_items" => 10, "keep" => "first" }.merge(configuration)
    instance = described_class.new(configuration: config)
    result =
      instance.execute(
        DiscourseWorkflows::NodeExecutionContext.new(input_items: input_items, node_context: {}),
      )
    result[0]
  end

  def make_items(count)
    Array.new(count) { |i| { "json" => { "index" => i } } }
  end

  describe "#execute" do
    it "keeps the first N items by default" do
      result = execute(make_items(5), "max_items" => 3)

      expect(result.length).to eq(3)
      expect(result[0]["json"]["index"]).to eq(0)
      expect(result[1]["json"]["index"]).to eq(1)
      expect(result[2]["json"]["index"]).to eq(2)
    end

    it "keeps the last N items when keep is last" do
      result = execute(make_items(5), "max_items" => 2, "keep" => "last")

      expect(result.length).to eq(2)
      expect(result[0]["json"]["index"]).to eq(3)
      expect(result[1]["json"]["index"]).to eq(4)
    end

    it "returns all items when max_items exceeds input size" do
      result = execute(make_items(3), "max_items" => 10)

      expect(result.length).to eq(3)
    end

    it "returns empty array when input is empty" do
      result = execute([], "max_items" => 5)

      expect(result).to eq([])
    end

    it "defaults to 10 items" do
      result = execute(make_items(15))

      expect(result.length).to eq(10)
    end

    it "handles max_items of 1" do
      result = execute(make_items(5), "max_items" => 1)

      expect(result.length).to eq(1)
      expect(result[0]["json"]["index"]).to eq(0)
    end

    it "handles max_items of 1 with keep last" do
      result = execute(make_items(5), "max_items" => 1, "keep" => "last")

      expect(result.length).to eq(1)
      expect(result[0]["json"]["index"]).to eq(4)
    end

    it "preserves item json structure" do
      items = [
        { "json" => { "name" => "Alice", "age" => 30 } },
        { "json" => { "name" => "Bob", "age" => 25 } },
      ]
      result = execute(items, "max_items" => 1)

      expect(result[0]["json"]).to eq({ "name" => "Alice", "age" => 30 })
    end
  end
end
