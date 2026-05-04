# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Log::V1 do
  describe "#execute" do
    it "passes input items through unchanged" do
      items = [{ "json" => { "name" => "Alice" } }, { "json" => { "count" => 42 } }]
      result =
        execute_node_result(
          configuration: {
            "entries" => [{ "key" => "tag", "value" => "hello" }],
          },
          input_items: items,
        )
      expect(result.primary_items(ports: described_class.ports)).to eq(items)
    end

    it "records structured key/value logs" do
      items = [{ "json" => { "id" => 1 } }]
      entries = [{ "key" => "user_id", "value" => "1" }, { "key" => "status", "value" => "ok" }]
      execute_node_result(configuration: { "entries" => entries }, input_items: items) do |ctx|
        expect(ctx.log.entries.size).to eq(2)
        expect(ctx.log.entries.first).to include(
          "level" => "info",
          "key" => "user_id",
          "value" => "1",
        )
        expect(ctx.log.entries.second).to include(
          "level" => "info",
          "key" => "status",
          "value" => "ok",
        )
      end
    end

    it "resolves expressions in entry values" do
      items = [{ "json" => { "user_name" => "Bob" } }]
      result =
        execute_node_result(
          configuration: {
            "entries" => [{ "key" => "name", "value" => "={{ $json.user_name }}" }],
          },
          input_items: items,
        ) do |ctx|
          expect(ctx.log.entries.first).to include(
            "level" => "info",
            "key" => "name",
            "value" => "Bob",
          )
        end
      expect(result.primary_items(ports: described_class.ports)).to eq(items)
    end

    it "handles empty entries gracefully" do
      items = [{ "json" => { "x" => 1 } }]
      result =
        execute_node_result(configuration: { "entries" => [] }, input_items: items) do |ctx|
          expect(ctx.log.entries).to be_empty
        end
      expect(result.primary_items(ports: described_class.ports)).to eq(items)
    end

    it "handles missing entries key" do
      items = [{ "json" => { "x" => 1 } }]
      result =
        execute_node_result(configuration: {}, input_items: items) do |ctx|
          expect(ctx.log.entries).to be_empty
        end
      expect(result.primary_items(ports: described_class.ports)).to eq(items)
    end
  end
end
