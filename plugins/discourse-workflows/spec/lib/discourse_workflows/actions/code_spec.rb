# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::Code::V1 do
  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:code")
    end
  end

  describe "#execute" do
    let(:context) { {} }
    let(:node_context) { {} }

    it "executes JavaScript and returns the result" do
      action = described_class.new(configuration: { "code" => 'return { greeting: "hello" };' })
      items = [{ "json" => { "name" => "world" } }]

      result = action.execute(context, input_items: items, node_context: node_context)

      expect(result.first["json"]["greeting"]).to eq("hello")
    end

    it "exposes $json with the current item data" do
      action = described_class.new(configuration: { "code" => "return { name: $json.name };" })
      items = [{ "json" => { "name" => "Alice" } }]

      result = action.execute(context, input_items: items, node_context: node_context)

      expect(result.first["json"]["name"]).to eq("Alice")
    end

    it "captures console.log output" do
      action =
        described_class.new(configuration: { "code" => 'console.log("debug message"); return {};' })
      items = [{ "json" => {} }]

      action.execute(context, input_items: items, node_context: node_context)

      expect(action.logs).to eq(["debug message"])
    end

    it "processes each input item independently" do
      action = described_class.new(configuration: { "code" => "return { doubled: $json.n * 2 };" })
      items = [{ "json" => { "n" => 3 } }, { "json" => { "n" => 5 } }]

      result = action.execute(context, input_items: items, node_context: node_context)

      expect(result.map { |r| r["json"]["doubled"] }).to eq([6, 10])
    end

    it "wraps non-hash return values" do
      action = described_class.new(configuration: { "code" => 'return "just a string";' })
      items = [{ "json" => {} }]

      result = action.execute(context, input_items: items, node_context: node_context)

      expect(result.first["json"]["result"]).to eq("just a string")
    end

    it "provides $input.all() to access all items" do
      action =
        described_class.new(configuration: { "code" => "return { count: $input.all().length };" })
      items = [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }]

      result = action.execute(context, input_items: items, node_context: node_context)

      expect(result.first["json"]["count"]).to eq(2)
    end

    it "accesses workflow variables via $vars" do
      Fabricate(:discourse_workflows_variable, key: "api_key", value: "secret123")

      action = described_class.new(configuration: { "code" => "return { key: $vars.api_key };" })
      items = [{ "json" => {} }]

      result = action.execute(context, input_items: items, node_context: node_context)

      expect(result.first["json"]["key"]).to eq("secret123")
    end

    it "raises on invalid JavaScript" do
      action = described_class.new(configuration: { "code" => "this is not valid js {{{" })
      items = [{ "json" => {} }]

      expect {
        action.execute(context, input_items: items, node_context: node_context)
      }.to raise_error(MiniRacer::ParseError)
    end
  end
end
