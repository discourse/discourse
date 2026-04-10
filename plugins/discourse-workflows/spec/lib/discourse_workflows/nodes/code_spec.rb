# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Code::V1 do
  fab!(:api_key_variable) do
    Fabricate(:discourse_workflows_variable, key: "api_key", value: "secret123")
  end

  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:code")
    end
  end

  def build_exec_ctx(items, resolver: nil, **kwargs)
    resolver ||=
      DiscourseWorkflows::ExpressionResolver.new({ "$json" => items.first&.dig("json") || {} })
    DiscourseWorkflows::NodeExecutionContext.new(input_items: items, resolver: resolver, **kwargs)
  end

  def execute_code(code, items: [{ "json" => {} }], **kwargs)
    action = described_class.new(configuration: { "code" => code })
    action.execute(build_exec_ctx(items, **kwargs))[0]
  end

  def execute_code_with_action(code, items: [{ "json" => {} }], **kwargs)
    action = described_class.new(configuration: kwargs.delete(:configuration) || { "code" => code })
    action.execute(build_exec_ctx(items, **kwargs))
    action
  end

  describe "#execute" do
    it "executes JavaScript and returns the result" do
      result =
        execute_code('return { greeting: "hello" };', items: [{ "json" => { "name" => "world" } }])

      expect(result.first["json"]["greeting"]).to eq("hello")
    end

    it "exposes $json with the current item data" do
      result =
        execute_code("return { name: $json.name };", items: [{ "json" => { "name" => "Alice" } }])

      expect(result.first["json"]["name"]).to eq("Alice")
    end

    it "caps console.log output at MAX_ENTRIES" do
      action =
        execute_code_with_action(
          "for (var i = 0; i < 300; i++) { console.log('line ' + i); } return {};",
        )

      expect(action.log.entries.size).to eq(DiscourseWorkflows::StepLog::MAX_ENTRIES + 1)
      expect(action.log.entries.last["message"]).to include("truncated")
    end

    it "captures console.log output" do
      action = execute_code_with_action('console.log("debug message"); return {};')

      expect(action.log.entries.size).to eq(1)
      expect(action.log.entries.first).to include("level" => "info", "message" => "debug message")
    end

    it "accumulates logs across all input items" do
      items = [{ "json" => { "n" => 1 } }, { "json" => { "n" => 2 } }]
      action = execute_code_with_action('console.log("item " + $json.n); return {};', items: items)

      expect(action.log.entries.map { |e| e["message"] }).to eq(["item 1", "item 2"])
    end

    it "captures console.warn as warn level" do
      action = execute_code_with_action('console.warn("careful"); return {};')

      expect(action.log.entries.first).to include("level" => "warn", "message" => "careful")
    end

    it "captures console.error as error level" do
      action = execute_code_with_action('console.error("broken"); return {};')

      expect(action.log.entries.first).to include("level" => "error", "message" => "broken")
      expect(action.log.errors?).to be(true)
    end

    it "processes each input item independently" do
      items = [{ "json" => { "n" => 3 } }, { "json" => { "n" => 5 } }]
      result = execute_code("return { doubled: $json.n * 2 };", items: items)

      expect(result.map { |r| r["json"]["doubled"] }).to eq([6, 10])
    end

    it "wraps non-hash return values" do
      result = execute_code('return "just a string";')

      expect(result.first["json"]["result"]).to eq("just a string")
    end

    it "provides $input.all() to access all items" do
      items = [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }]
      result = execute_code("return { count: $input.all().length };", items: items)

      expect(result.first["json"]["count"]).to eq(2)
    end

    it "accesses workflow variables via $vars" do
      result = execute_code("return { key: $vars.api_key };")

      expect(result.first["json"]["key"]).to eq("secret123")
    end

    it "filters secret site settings from $site_settings" do
      result = execute_code("return { val: $site_settings.discourse_connect_secret };")

      expect(result.first["json"]["val"]).to eq("[FILTERED]")
    end

    it "filters hidden site settings from $site_settings" do
      result = execute_code("return { val: $site_settings.vapid_public_key };")

      expect(result.first["json"]["val"]).to eq("[FILTERED]")
    end

    it "filters internal context keys from $() node output accessor" do
      result = execute_code('return $("__resume_token");')

      expect(result.first["json"]["item"]["json"]).to eq({})
    end

    it "exposes $execution variables" do
      resolver =
        DiscourseWorkflows::ExpressionResolver.new(
          { "$json" => {}, "_execution" => { "id" => 99, "workflow_name" => "Test Flow" } },
        )

      result =
        execute_code(
          "return { id: $execution.id, name: $execution.workflow_name };",
          resolver: resolver,
        )

      expect(result.first["json"]["id"]).to eq(99)
      expect(result.first["json"]["name"]).to eq("Test Flow")
    end

    it "allows accessing normal node outputs via $()" do
      resolver =
        DiscourseWorkflows::ExpressionResolver.new(
          { "$json" => {}, "MyNode" => [{ "json" => { "data" => "visible" } }] },
        )

      result = execute_code('return $("MyNode").item.json;', resolver: resolver)

      expect(result.first["json"]["data"]).to eq("visible")
    end

    it "processes multiple items without creating a sandbox per item" do
      items = (1..5).map { |i| { "json" => { "x" => i } } }
      result = execute_code("return { val: $json.x * 2 };", items: items)

      expect(result.map { |r| r["json"]["val"] }).to eq([2, 4, 6, 8, 10])
    end

    it "raises on invalid JavaScript" do
      expect { execute_code("this is not valid js {{{") }.to raise_error(MiniRacer::ParseError)
    end
  end
end
