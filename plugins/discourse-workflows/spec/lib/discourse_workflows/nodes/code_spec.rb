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

  def build_resolver(items)
    DiscourseWorkflows::ExpressionResolver.new({ "$json" => items.first&.dig("json") || {} })
  end

  describe "#execute" do
    let(:context) { {} }
    let(:node_context) { {} }

    it "executes JavaScript and returns the result" do
      action = described_class.new(configuration: { "code" => 'return { greeting: "hello" };' })
      items = [{ "json" => { "name" => "world" } }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.first["json"]["greeting"]).to eq("hello")
    end

    it "exposes $json with the current item data" do
      action = described_class.new(configuration: { "code" => "return { name: $json.name };" })
      items = [{ "json" => { "name" => "Alice" } }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.first["json"]["name"]).to eq("Alice")
    end

    it "caps console.log output at MAX_ENTRIES" do
      action =
        described_class.new(
          configuration: {
            "code" => "for (var i = 0; i < 300; i++) { console.log('line ' + i); } return {};",
          },
        )
      items = [{ "json" => {} }]

      action.execute(
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: items,
          node_context: node_context,
          resolver: build_resolver(items),
        ),
      )

      expect(action.log.entries.size).to eq(DiscourseWorkflows::StepLog::MAX_ENTRIES + 1)
      expect(action.log.entries.last["message"]).to include("truncated")
    end

    it "captures console.log output" do
      action =
        described_class.new(configuration: { "code" => 'console.log("debug message"); return {};' })
      items = [{ "json" => {} }]

      action.execute(
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: items,
          node_context: node_context,
          resolver: build_resolver(items),
        ),
      )

      expect(action.log.entries.size).to eq(1)
      expect(action.log.entries.first).to include("level" => "info", "message" => "debug message")
    end

    it "accumulates logs across all input items" do
      action =
        described_class.new(
          configuration: {
            "code" => 'console.log("item " + $json.n); return {};',
          },
        )
      items = [{ "json" => { "n" => 1 } }, { "json" => { "n" => 2 } }]

      action.execute(
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: items,
          node_context: node_context,
          resolver: build_resolver(items),
        ),
      )

      expect(action.log.entries.map { |e| e["message"] }).to eq(["item 1", "item 2"])
    end

    it "captures console.warn as warn level" do
      action =
        described_class.new(configuration: { "code" => 'console.warn("careful"); return {};' })
      items = [{ "json" => {} }]

      action.execute(
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: items,
          node_context: node_context,
          resolver: build_resolver(items),
        ),
      )

      expect(action.log.entries.first).to include("level" => "warn", "message" => "careful")
    end

    it "captures console.error as error level" do
      action =
        described_class.new(configuration: { "code" => 'console.error("broken"); return {};' })
      items = [{ "json" => {} }]

      action.execute(
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: items,
          node_context: node_context,
          resolver: build_resolver(items),
        ),
      )

      expect(action.log.entries.first).to include("level" => "error", "message" => "broken")
      expect(action.log.errors?).to be(true)
    end

    it "processes each input item independently" do
      action = described_class.new(configuration: { "code" => "return { doubled: $json.n * 2 };" })
      items = [{ "json" => { "n" => 3 } }, { "json" => { "n" => 5 } }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.map { |r| r["json"]["doubled"] }).to eq([6, 10])
    end

    it "wraps non-hash return values" do
      action = described_class.new(configuration: { "code" => 'return "just a string";' })
      items = [{ "json" => {} }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.first["json"]["result"]).to eq("just a string")
    end

    it "provides $input.all() to access all items" do
      action =
        described_class.new(configuration: { "code" => "return { count: $input.all().length };" })
      items = [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.first["json"]["count"]).to eq(2)
    end

    it "accesses workflow variables via $vars" do
      action = described_class.new(configuration: { "code" => "return { key: $vars.api_key };" })
      items = [{ "json" => {} }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.first["json"]["key"]).to eq("secret123")
    end

    it "filters secret site settings from $site_settings" do
      action =
        described_class.new(
          configuration: {
            "code" => "return { val: $site_settings.discourse_connect_secret };",
          },
        )
      items = [{ "json" => {} }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.first["json"]["val"]).to eq("[FILTERED]")
    end

    it "filters hidden site settings from $site_settings" do
      action =
        described_class.new(
          configuration: {
            "code" => "return { val: $site_settings.vapid_public_key };",
          },
        )
      items = [{ "json" => {} }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.first["json"]["val"]).to eq("[FILTERED]")
    end

    it "filters internal context keys from $() node output accessor" do
      context_with_internal = {
        "__resume_token" => "secret-token-123",
        "MyNode" => [{ "json" => { "data" => "visible" } }],
      }
      action = described_class.new(configuration: { "code" => 'return $("__resume_token");' })
      items = [{ "json" => {} }]

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.first["json"]["item"]["json"]).to eq({})
    end

    it "allows accessing normal node outputs via $()" do
      action = described_class.new(configuration: { "code" => 'return $("MyNode").item.json;' })
      items = [{ "json" => {} }]
      resolver =
        DiscourseWorkflows::ExpressionResolver.new(
          { "$json" => {}, "MyNode" => [{ "json" => { "data" => "visible" } }] },
        )

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: {
            },
            resolver: resolver,
          ),
        )[
          0
        ]

      expect(result.first["json"]["data"]).to eq("visible")
    end

    it "processes multiple items without creating a sandbox per item" do
      action = described_class.new(configuration: { "code" => "return { val: $json.x * 2 };" })
      items = (1..5).map { |i| { "json" => { "x" => i } } }

      result =
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: {
            },
            resolver: build_resolver(items),
          ),
        )[
          0
        ]

      expect(result.map { |r| r["json"]["val"] }).to eq([2, 4, 6, 8, 10])
    end

    it "raises on invalid JavaScript" do
      action = described_class.new(configuration: { "code" => "this is not valid js {{{" })
      items = [{ "json" => {} }]

      expect {
        action.execute(
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: items,
            node_context: node_context,
            resolver: build_resolver(items),
          ),
        )
      }.to raise_error(MiniRacer::ParseError)
    end
  end
end
