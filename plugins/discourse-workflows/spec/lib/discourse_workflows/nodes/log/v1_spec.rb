# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Log::V1 do
  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({}) }
  after { sandbox.dispose }

  def execute(input_items, configuration = {})
    config = { "entries" => [] }.merge(configuration)
    instance = described_class.new(configuration: config)
    item_json = input_items.first&.dig("json") || {}
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item_json }, sandbox: sandbox)
    exec_ctx =
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: input_items,
        node_context: {
        },
        resolver: resolver,
        configuration: config,
        property_schema: described_class.property_schema,
      )
    result = instance.execute(exec_ctx)
    [result[0], exec_ctx.log]
  end

  describe "#execute" do
    it "passes input items through unchanged" do
      items = [{ "json" => { "name" => "Alice" } }, { "json" => { "count" => 42 } }]
      result, = execute(items, "entries" => [{ "key" => "tag", "value" => "hello" }])

      expect(result).to eq(items)
    end

    it "records structured key/value logs" do
      items = [{ "json" => { "id" => 1 } }]
      entries = [{ "key" => "user_id", "value" => "1" }, { "key" => "status", "value" => "ok" }]
      _, log = execute(items, "entries" => entries)

      expect(log.entries.size).to eq(2)
      expect(log.entries.first).to include("level" => "info", "key" => "user_id", "value" => "1")
      expect(log.entries.second).to include("level" => "info", "key" => "status", "value" => "ok")
    end

    it "resolves expressions in entry values" do
      items = [{ "json" => { "user_name" => "Bob" } }]
      result, log =
        execute(items, "entries" => [{ "key" => "name", "value" => "={{ $json.user_name }}" }])

      expect(result).to eq(items)
      expect(log.entries.first).to include("level" => "info", "key" => "name", "value" => "Bob")
    end

    it "handles empty entries gracefully" do
      items = [{ "json" => { "x" => 1 } }]
      result, log = execute(items, "entries" => [])

      expect(result).to eq(items)
      expect(log.entries).to be_empty
    end

    it "handles missing entries key" do
      items = [{ "json" => { "x" => 1 } }]
      result, log = execute(items)

      expect(result).to eq(items)
      expect(log.entries).to be_empty
    end
  end
end
