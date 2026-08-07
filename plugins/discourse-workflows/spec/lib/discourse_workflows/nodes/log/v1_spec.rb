# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Log::V1 do
  def entries(*rows)
    { "values" => rows }
  end

  describe "#execute" do
    it "passes input items through" do
      items = [{ "json" => { "name" => "Alice" } }, { "json" => { "count" => 42 } }]
      result =
        execute_node_output(
          configuration: {
            "entries" => entries({ "key" => "tag", "value" => "hello" }),
          },
          input_items: items,
        )
      expect(result.first).to eq(items)
    end

    it "records structured key/value logs" do
      items = [{ "json" => { "id" => 1 } }]
      log_entries =
        entries({ "key" => "user_id", "value" => "1" }, { "key" => "status", "value" => "ok" })
      execute_node_output(configuration: { "entries" => log_entries }, input_items: items) do |ctx|
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
        execute_node_output(
          configuration: {
            "entries" => entries({ "key" => "name", "value" => "={{ $json.user_name }}" }),
          },
          input_items: items,
        ) do |ctx|
          expect(ctx.log.entries.first).to include(
            "level" => "info",
            "key" => "name",
            "value" => "Bob",
          )
        end
      expect(result.first).to eq(items)
    end

    it "handles empty entries gracefully" do
      items = [{ "json" => { "x" => 1 } }]
      result =
        execute_node_output(configuration: { "entries" => entries }, input_items: items) do |ctx|
          expect(ctx.log.entries).to be_empty
        end
      expect(result.first).to eq(items)
    end

    it "handles missing entries key" do
      items = [{ "json" => { "x" => 1 } }]
      result =
        execute_node_output(configuration: {}, input_items: items) do |ctx|
          expect(ctx.log.entries).to be_empty
        end
      expect(result.first).to eq(items)
    end

    it "defaults to runOnceForEachItem, resolving expressions per item" do
      items = [
        { "json" => { "name" => "Alice" } },
        { "json" => { "name" => "Bob" } },
        { "json" => { "name" => "Carol" } },
      ]
      execute_node_output(
        configuration: {
          "entries" => entries({ "key" => "name", "value" => "={{ $json.name }}" }),
        },
        input_items: items,
      ) do |ctx|
        expect(ctx.log.entries.map { |entry| entry["value"] }).to eq(%w[Alice Bob Carol])
        expect(ctx.log.entries.map { |entry| entry["key"] }).to eq(%w[name name name])
      end
    end

    it "emits items.size * entries.size logs in runOnceForEachItem mode" do
      items = [{ "json" => { "id" => 1 } }, { "json" => { "id" => 2 } }]
      log_entries =
        entries(
          { "key" => "id", "value" => "={{ $json.id }}" },
          { "key" => "tag", "value" => "static" },
        )
      execute_node_output(
        configuration: {
          "mode" => "runOnceForEachItem",
          "entries" => log_entries,
        },
        input_items: items,
      ) do |ctx|
        expect(ctx.log.entries.size).to eq(4)
        expect(ctx.log.entries.map { |entry| [entry["key"], entry["value"]] }).to eq(
          [%w[id 1], %w[tag static], %w[id 2], %w[tag static]],
        )
      end
    end

    it "logs entries once in runOnceForAllItems mode" do
      items = [
        { "json" => { "name" => "Alice" } },
        { "json" => { "name" => "Bob" } },
        { "json" => { "name" => "Carol" } },
      ]
      execute_node_output(
        configuration: {
          "mode" => "runOnceForAllItems",
          "entries" => entries({ "key" => "name", "value" => "={{ $json.name }}" }),
        },
        input_items: items,
      ) do |ctx|
        expect(ctx.log.entries.size).to eq(1)
        expect(ctx.log.entries.first).to include("key" => "name", "value" => "Alice")
      end
    end

    it "still logs once when input items are empty" do
      result =
        execute_node_output(
          configuration: {
            "entries" => entries({ "key" => "marker", "value" => "ran" }),
          },
          input_items: [],
        ) do |ctx|
          expect(ctx.log.entries.size).to eq(1)
          expect(ctx.log.entries.first).to include("key" => "marker", "value" => "ran")
        end
      expect(result.first).to eq([])
    end
  end
end
